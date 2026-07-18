import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:obra_check/models/inspection_record.dart';
import 'package:obra_check/services/inspection_draft_mapper_service.dart';

void main() {
  late Directory tempDir;
  final mapper = InspectionDraftMapperService.instance;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('obra_check_draft_mapper_');
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

  InspectionRecord buildRecord({
    required String id,
    required String status,
    List<InspectionItemResult>? itens,
  }) {
    final now = DateTime.now();
    return InspectionRecord(
      id: id,
      obra: 'Arsen Sabiá',
      torre: 'Paris',
      andar: 1,
      apto: '101',
      localRef: 'APTO_101',
      fvsCodigo: '1.1',
      fvsNome: 'Teste',
      itens: itens ?? const [],
      createdAt: now,
      updatedAt: now,
      status: status,
      finalizedAt: status == InspectionRecord.statusFinal ? now : null,
      locked: status == InspectionRecord.statusFinal,
      lockedAt: status == InspectionRecord.statusFinal ? now : null,
      actionType: InspectionRecord.actionTypeFromStatus(status),
      actionByUid: 'uid',
      actionByName: 'Nome',
      actionByCargo: 'Cargo',
      actionAt: now,
      deleted: false,
      pendingSync: true,
      deletedAt: null,
      ncCompanyId: null,
      ncCompanyName: null,
    );
  }

  group('resolveDraftRecord()', () {
    test('encontra draft pela chave salva em prefs', () async {
      final inspections = Hive.box<InspectionRecord>('inspections');
      final prefs = Hive.box('prefs');

      final record = buildRecord(
        id: 'draft:principal',
        status: InspectionRecord.statusDraft,
      );
      await inspections.put(record.id, record);
      await prefs.put('draftKey', record.id);

      final resolved = mapper.resolveDraftRecord(
        inspectionsBox: inspections,
        prefs: prefs,
        draftKey: 'draftKey',
        fallbackRecordId: 'fallback',
      );

      expect(resolved, isNotNull);
      expect(resolved!.id, record.id);
      expect(resolved.isDraft, isTrue);
    });

    test('funciona com fallback quando chave principal não existe', () async {
      final inspections = Hive.box<InspectionRecord>('inspections');
      final prefs = Hive.box('prefs');

      final fallback = buildRecord(
        id: 'draft:fallback',
        status: InspectionRecord.statusDraft,
      );
      await inspections.put(fallback.id, fallback);

      final resolved = mapper.resolveDraftRecord(
        inspectionsBox: inspections,
        prefs: prefs,
        draftKey: 'draftKey',
        fallbackRecordId: fallback.id,
      );

      expect(resolved, isNotNull);
      expect(resolved!.id, fallback.id);
    });

    test('retorna null quando não existir draft válido', () async {
      final inspections = Hive.box<InspectionRecord>('inspections');
      final prefs = Hive.box('prefs');

      final finalRecord = buildRecord(
        id: 'record:final',
        status: InspectionRecord.statusFinal,
      );
      await inspections.put(finalRecord.id, finalRecord);
      await prefs.put('draftKey', finalRecord.id);

      final resolved = mapper.resolveDraftRecord(
        inspectionsBox: inspections,
        prefs: prefs,
        draftKey: 'draftKey',
        fallbackRecordId: 'fallback:missing',
      );

      expect(resolved, isNull);
    });
  });

  group('mapRecordToFormState()', () {
    test('reconstrói status, observações e fotos da estrutura atual', () {
      final record = buildRecord(
        id: 'draft:map:novo',
        status: InspectionRecord.statusDraft,
        itens: [
          InspectionItemResult(
            index: 0,
            descricao: 'Item 0',
            dica: 'Dica 0',
            status: 'nok',
            obs: 'Com problema',
            photos: [
              InspectionPhotoData(
                photoUrl: 'https://server/foto.jpg',
                storagePath: 'obras/x/foto.jpg',
                localPath: '',
                pendingSync: false,
              ),
            ],
          ),
          InspectionItemResult(
            index: 1,
            descricao: 'Item 1',
            dica: 'Dica 1',
            status: 'okAfterFix',
            obs: 'Corrigido',
          ),
        ],
      );

      final formState = mapper.mapRecordToFormState(record);

      expect(formState.statusByIndex[0], 'nok');
      expect(formState.statusByIndex[1], 'okAfterFix');
      expect(formState.obsByIndex[0], 'Com problema');
      expect(formState.obsByIndex[1], 'Corrigido');
      expect(formState.photosByIndex[0], isNotNull);
      expect(formState.photosByIndex[0]!.length, 1);
      expect(
        formState.photosByIndex[0]!.first.photoUrl,
        'https://server/foto.jpg',
      );
    });

    test('trata registros incompletos sem quebrar', () {
      final record = buildRecord(
        id: 'draft:map:incompleto',
        status: InspectionRecord.statusDraft,
        itens: [
          InspectionItemResult(
            index: 2,
            descricao: 'Item 2',
            dica: 'Dica 2',
            status: 'ok',
            obs: '',
          ),
        ],
      );

      final formState = mapper.mapRecordToFormState(record);

      expect(formState.statusByIndex[2], 'ok');
      expect(formState.obsByIndex.containsKey(2), isFalse);
      expect(formState.photosByIndex.containsKey(2), isFalse);
    });
  });

  group('compatibilidade legada de photoPaths', () {
    test('converte photoPaths legados corretamente', () {
      final record = buildRecord(
        id: 'draft:legado',
        status: InspectionRecord.statusDraft,
        itens: [
          InspectionItemResult(
            index: 0,
            descricao: 'Item 0',
            dica: 'Dica 0',
            status: 'nok',
            obs: 'NC',
            photoPaths: [
              'https://firebasestorage.googleapis.com/v0/b/proj/o/obras%2Fabc.jpg?alt=media',
              '/data/user/0/app/cache/local.jpg',
            ],
          ),
        ],
      );

      final formState = mapper.mapRecordToFormState(record);
      final photos = formState.photosByIndex[0]!;

      expect(photos.length, 2);
      expect(photos.first.photoUrl.startsWith('https://'), isTrue);
      expect(photos.first.pendingSync, isFalse);
      expect(photos.last.localPath, '/data/user/0/app/cache/local.jpg');
      expect(photos.last.pendingSync, isTrue);
    });

    test(
      'prioriza estrutura nova quando existem fotos mistas (nova + legado)',
      () {
        final record = buildRecord(
          id: 'draft:misto',
          status: InspectionRecord.statusDraft,
          itens: [
            InspectionItemResult(
              index: 1,
              descricao: 'Item 1',
              dica: 'Dica 1',
              status: 'nok',
              obs: 'NC',
              photoPaths: ['/tmp/legado.jpg'],
              photos: [
                InspectionPhotoData(
                  photoUrl: 'https://server/new.jpg',
                  storagePath: 'obras/new.jpg',
                  localPath: '',
                  pendingSync: false,
                ),
              ],
            ),
          ],
        );

        final formState = mapper.mapRecordToFormState(record);
        final photos = formState.photosByIndex[1]!;

        expect(photos.length, 1);
        expect(photos.first.photoUrl, 'https://server/new.jpg');
        expect(photos.first.localPath, '');
      },
    );

    test('não quebra com photoPaths antigos parciais/vazios', () {
      final record = buildRecord(
        id: 'draft:parcial',
        status: InspectionRecord.statusDraft,
        itens: [
          InspectionItemResult(
            index: 3,
            descricao: 'Item 3',
            dica: 'Dica 3',
            status: 'ok',
            obs: '',
            photoPaths: ['', '   '],
          ),
        ],
      );

      final formState = mapper.mapRecordToFormState(record);
      expect(formState.photosByIndex.containsKey(3), isFalse);
    });
  });

  group('consistência de formulário', () {
    test('estado restaurado é compatível com uso da InspectionScreen', () {
      final record = buildRecord(
        id: 'draft:screen',
        status: InspectionRecord.statusDraft,
        itens: [
          InspectionItemResult(
            index: 0,
            descricao: 'Item 0',
            dica: 'Dica 0',
            status: 'nok',
            obs: 'Obs 0',
          ),
          InspectionItemResult(
            index: 4,
            descricao: 'Item 4',
            dica: 'Dica 4',
            status: 'okAfterFix',
            obs: 'Obs 4',
          ),
        ],
      );

      final formState = mapper.mapRecordToFormState(record);

      expect(formState.statusByIndex[0], 'nok');
      expect(formState.statusByIndex[4], 'okAfterFix');
      expect(formState.statusByIndex.containsKey(1), isFalse);
      expect(formState.obsByIndex[0], 'Obs 0');
      expect(formState.obsByIndex[4], 'Obs 4');
      // Itens não salvos permanecem neutros na tela (sem chave no mapa).
      expect(formState.obsByIndex.containsKey(1), isFalse);
      expect(record.isDraft, isTrue);
      expect(record.isLockedState, isFalse);
    });
  });
}
