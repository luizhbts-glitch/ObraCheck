import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:obra_check/models/inspection_record.dart';
import 'package:obra_check/screens/open_nc_screen.dart';
import 'package:obra_check/screens/reports_screen.dart';
import 'package:obra_check/screens/select_fvs_screen.dart';

InspectionRecord buildInspection({
  required String id,
  required String fvsCodigo,
  required String fvsNome,
  required String localRef,
  required String torre,
  required int andar,
  String inspectionElement = '',
  String itemStatus = 'ok',
}) {
  final now = DateTime.now();
  return InspectionRecord(
    id: id,
    obra: 'Arsen Sabiá',
    torre: torre,
    andar: andar,
    apto: localRef.replaceFirst('APTO_', ''),
    localRef: localRef,
    fvsCodigo: fvsCodigo,
    fvsNome: fvsNome,
    inspectionElement: inspectionElement,
    itens: [
      InspectionItemResult(
        index: 0,
        descricao: 'Item 1',
        dica: '',
        status: itemStatus,
        obs: '',
      ),
    ],
    createdAt: now,
    updatedAt: now,
    status: InspectionRecord.statusFinal,
    finalizedAt: now,
    locked: true,
    lockedAt: now,
    actionType: 'finalizou',
    actionByUid: 'uid',
    actionByName: 'Usuário',
    actionByCargo: 'Engenheiro',
    actionAt: now,
    deleted: false,
    pendingSync: false,
    deletedAt: null,
    ncCompanyId: null,
    ncCompanyName: null,
  );
}

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('obra_check_widget_element_');
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

  group('SelectFvsScreen', () {
    testWidgets('FVS que exige elemento exibe seletor e retorna SelectFvsResult com elemento', (tester) async {
      await Hive.box('prefs').put('last_fvs_codigo', '3.3');

      await tester.pumpWidget(const MaterialApp(home: SelectFvsScreen()));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Elemento da inspeção'), findsOneWidget);
      final confirmBtn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Confirmar FVS'),
      );
      expect(confirmBtn.onPressed, isNotNull);
    });

    testWidgets('FVS que não exige elemento confirma sem seleção adicional', (tester) async {
      await Hive.box('prefs').put('last_fvs_codigo', '4.2');

      await tester.pumpWidget(const MaterialApp(home: SelectFvsScreen()));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Elemento da inspeção'), findsNothing);
      final confirmBtn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Confirmar FVS'),
      );
      expect(confirmBtn.onPressed, isNotNull);
    });
  });

  group('ReportsScreen', () {
    testWidgets('exibe registros com e sem elemento e filtra por elemento / sem elemento', (tester) async {
      final box = Hive.box<InspectionRecord>('inspections');
      await box.put(
        'r1',
        buildInspection(
          id: 'r1',
          fvsCodigo: '3.3',
          fvsNome: 'Concretagem de peça estrutural',
          localRef: 'APTO_401',
          torre: 'Paris',
          andar: 4,
          inspectionElement: 'Pilar',
          itemStatus: 'ok',
        ),
      );
      await box.put(
        'r2',
        buildInspection(
          id: 'r2',
          fvsCodigo: '4.2',
          fvsNome: 'Execução de reboco',
          localRef: 'APTO_402',
          torre: 'Paris',
          andar: 4,
          inspectionElement: '',
          itemStatus: 'ok',
        ),
      );

      await tester.pumpWidget(const MaterialApp(home: ReportsScreen()));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('Elemento: Pilar'), findsOneWidget);
      expect(find.text('Local Apto 402'), findsOneWidget);

      await tester.tap(find.text('Elemento: Todos'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Pilar').last);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Elemento: Pilar'), findsOneWidget);
      expect(find.textContaining('Elemento: Pilar'), findsOneWidget);
      expect(find.text('Local Apto 402'), findsNothing);

      await tester.tap(find.text('Elemento: Pilar'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Sem elemento').last);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Elemento: Sem elemento'), findsOneWidget);
      expect(find.textContaining('Elemento: Pilar'), findsNothing);
      expect(find.text('Local Apto 402'), findsOneWidget);
    });
  });

  group('OpenNcScreen', () {
    testWidgets('diferencia NC com elemento e aplica filtro por elemento mantendo legado', (tester) async {
      final records = <InspectionRecord>[
        buildInspection(
          id: 'n1',
          fvsCodigo: '3.3',
          fvsNome: 'Concretagem de peça estrutural',
          localRef: 'APTO_401',
          torre: 'Paris',
          andar: 4,
          inspectionElement: 'Pilar',
          itemStatus: 'nok',
        ),
        buildInspection(
          id: 'n2',
          fvsCodigo: '3.3',
          fvsNome: 'Concretagem de peça estrutural',
          localRef: 'APTO_402',
          torre: 'Paris',
          andar: 4,
          inspectionElement: '',
          itemStatus: 'nok',
        ),
      ];

      await tester.pumpWidget(MaterialApp(home: OpenNcScreen(records: records)));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('FVS 3.3').first);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('401 • Pilar'), findsOneWidget);
      expect(find.text('402'), findsOneWidget);

      await tester.tap(find.text('Elemento: Todos'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Pilar').last);
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('FVS 3.3').first);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('401 • Pilar'), findsOneWidget);
      expect(find.text('402'), findsNothing);

      await tester.tap(find.text('Elemento: Pilar'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Sem elemento').last);
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('FVS 3.3').first);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('401 • Pilar'), findsNothing);
      expect(find.text('402'), findsOneWidget);
    });
  });
}

