import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:obra_check/data/fvs_catalog.dart';
import 'package:obra_check/models/inspection_record.dart';
import 'package:obra_check/services/inspection_workflow_service.dart';
import 'package:obra_check/services/user_profile_service.dart';

void main() {
  late Directory tempDir;
  final service = InspectionWorkflowService.instance;

  const user = UserProfileData(
    uid: 'uid_teste',
    nome: 'Usuário Teste',
    cargo: 'Engenheiro',
    email: 'teste@obra.com',
  );

  final template = FvsCatalog.all.first;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('obra_check_tests_');
    Hive.init(tempDir.path);

    try {
      Hive.registerAdapter(InspectionRecordAdapter());
    } catch (_) {}
    try {
      Hive.registerAdapter(InspectionItemResultAdapter());
    } catch (_) {}
    try {
      Hive.registerAdapter(InspectionPhotoDataAdapter());
    } catch (_) {}
  });

  setUp(() async {
    final inspections = await Hive.openBox<InspectionRecord>('inspections');
    final prefs = await Hive.openBox('prefs');
    await inspections.clear();
    await prefs.clear();
  });

  tearDownAll(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('composeItems()', () {
    test('monta itens com status, observação e fotos corretamente', () {
      final statusByIndex = <int, String>{0: 'nok', 1: 'okAfterFix'};
      final obsByIndex = <int, String>{
        0: 'Fissura encontrada',
        1: 'Corrigido em campo',
      };
      final photosByIndex = <int, List<InspectionPhotoData>>{
        0: const [
          InspectionPhotoData(
            photoUrl: '',
            storagePath: '',
            localPath: '/tmp/foto1.jpg',
            pendingSync: true,
          ),
        ],
      };

      final itens = service.composeItems(
        template: template,
        statusByIndex: statusByIndex,
        obsByIndex: obsByIndex,
        photosByIndex: photosByIndex,
      );

      expect(itens.length, template.itens.length);
      expect(itens[0].status, 'nok');
      expect(itens[0].obs, 'Fissura encontrada');
      expect(itens[0].photos.length, 1);
      expect(itens[0].photoPaths, ['/tmp/foto1.jpg']);
      expect(itens[1].status, 'okAfterFix');
      expect(itens[1].obs, 'Corrigido em campo');
    });
  });

  group('validateFinalize()', () {
    test('falha quando existir item não marcado', () {
      final result = service.validateFinalize(
        template: template,
        statusByIndex: {0: 'ok'},
        obsByIndex: const {},
      );

      expect(result.hasUnmarked, isTrue);
      expect(result.canFinalize, isFalse);
    });

    test('falha quando existir NOK sem observação', () {
      final status = <int, String>{
        for (int i = 0; i < template.itens.length; i++) i: 'ok',
      };
      status[0] = 'nok';

      final result = service.validateFinalize(
        template: template,
        statusByIndex: status,
        obsByIndex: const {},
      );

      expect(result.hasUnmarked, isFalse);
      expect(result.nokWithoutObs, contains(0));
      expect(result.canFinalize, isFalse);
    });

    test('passa quando todos os itens estão válidos', () {
      final status = <int, String>{
        for (int i = 0; i < template.itens.length; i++) i: 'ok',
      };

      final result = service.validateFinalize(
        template: template,
        statusByIndex: status,
        obsByIndex: const {},
      );

      expect(result.canFinalize, isTrue);
      expect(result.hasUnmarked, isFalse);
      expect(result.nokWithoutObs, isEmpty);
    });
  });

  group('hasNc()', () {
    test('retorna true quando houver pelo menos um NOK', () {
      final itens = [
        InspectionItemResult(
          index: 0,
          descricao: 'Item 1',
          dica: 'Dica 1',
          status: 'nok',
          obs: 'Com problema',
        ),
      ];

      expect(service.hasNc(itens), isTrue);
    });

    test('retorna false quando não houver NOK', () {
      final itens = [
        InspectionItemResult(
          index: 0,
          descricao: 'Item 1',
          dica: 'Dica 1',
          status: 'ok',
          obs: '',
        ),
      ];

      expect(service.hasNc(itens), isFalse);
    });
  });

  group('saveDraft()', () {
    test('salva com status draft, pendingSync e dados esperados', () async {
      final itens = service.composeItems(
        template: template,
        statusByIndex: {0: 'nok'},
        obsByIndex: {0: 'NC registrada'},
        photosByIndex: const {},
      );

      const draftKey = 'draft:Arsen Sabiá:Paris:1:APTO_101:1.1';
      const recordId = 'draft:Arsen Sabiá:Paris:1:APTO_101:1.1';

      final result = await service.saveDraft(
        location: {
          'torre': 'Paris',
          'andar': 1,
          'apto': '101',
          'localRef': 'APTO_101',
        },
        template: template,
        draftKey: draftKey,
        draftRecordId: recordId,
        inspectionElement: 'Pilar',
        itens: itens,
        user: user,
      );

      final box = Hive.box<InspectionRecord>('inspections');
      final saved = box.get(recordId);
      final prefs = Hive.box('prefs');

      expect(result.status, InspectionRecord.statusDraft);
      expect(result.pendingSync, isTrue);
      expect(service.hasNc(result.itens), isTrue);

      expect(saved, isNotNull);
      expect(saved!.status, InspectionRecord.statusDraft);
      expect(saved.pendingSync, isTrue);
      expect(saved.actionByName, user.nome);
      expect(saved.itens.first.status, 'nok');
      expect(saved.normalizedInspectionElement, 'Pilar');

      expect(prefs.get(draftKey), recordId);
      expect(prefs.get('inspection_synced_$recordId'), isFalse);
    });
  });

  group('saveFinalized()', () {
    test(
      'salva com status final, finalizedAt e pendingSync corretamente',
      () async {
        final itensDraft = service.composeItems(
          template: template,
          statusByIndex: {0: 'nok'},
          obsByIndex: {0: 'NC inicial'},
          photosByIndex: const {},
        );

        const draftKey = 'draft:Arsen Sabiá:Paris:2:APTO_201:1.1';
        const recordId = 'draft:Arsen Sabiá:Paris:2:APTO_201:1.1';

        await service.saveDraft(
          location: {
            'torre': 'Paris',
            'andar': 2,
            'apto': '201',
            'localRef': 'APTO_201',
          },
          template: template,
          draftKey: draftKey,
          draftRecordId: recordId,
          inspectionElement: 'Viga',
          itens: itensDraft,
          user: user,
        );

        final itensFinal = service.composeItems(
          template: template,
          statusByIndex: {
            for (int i = 0; i < template.itens.length; i++) i: 'ok',
          },
          obsByIndex: const {},
          photosByIndex: const {},
        );

        final result = await service.saveFinalized(
          location: {
            'torre': 'Paris',
            'andar': 2,
            'apto': '201',
            'localRef': 'APTO_201',
          },
          template: template,
          draftKey: draftKey,
          draftRecordId: recordId,
          currentRecordId: recordId,
          inspectionElement: 'Viga',
          itens: itensFinal,
          user: user,
        );

        final box = Hive.box<InspectionRecord>('inspections');
        final saved = box.get(recordId);
        final prefs = Hive.box('prefs');

        expect(result.status, InspectionRecord.statusFinal);
        expect(result.normalizedInspectionElement, 'Viga');
        expect(result.finalizedAt, isNotNull);
        expect(result.pendingSync, isTrue);
        expect(service.hasNc(result.itens), isFalse);

        expect(saved, isNotNull);
        expect(saved!.status, InspectionRecord.statusFinal);
        expect(saved.finalizedAt, isNotNull);
        expect(saved.pendingSync, isTrue);
        expect(saved.itens.every((item) => item.status == 'ok'), isTrue);

        expect(prefs.get(draftKey), isNull);
        expect(prefs.get('inspection_synced_$recordId'), isFalse);
      },
    );
  });
}
