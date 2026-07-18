import 'package:flutter_test/flutter_test.dart';
import 'package:obra_check/models/inspection_record.dart';

InspectionRecord _buildRecord({
  required String id,
  required String status,
  String projectId = 'obra_a',
  String torre = 'Paris',
  String apto = '501',
  String? localRef,
  String fvsCodigo = '4.1',
  String? operationalSheetId,
  DateTime? createdAt,
  DateTime? finalizedAt,
}) {
  return InspectionRecord(
    obra: 'Obra A',
    torre: torre,
    andar: 5,
    apto: apto,
    fvsCodigo: fvsCodigo,
    fvsNome: 'Estrutura',
    itens: const [],
    createdAt: createdAt ?? DateTime(2026, 7, 17, 8, 0),
    id: id,
    updatedAt: createdAt ?? DateTime(2026, 7, 17, 8, 0),
    status: status,
    localRef: localRef,
    projectId: projectId,
    operationalSheetId: operationalSheetId,
    finalizedAt: finalizedAt,
  );
}

void main() {
  group('InspectionRecord.inspectionLogicalKey (evita FVS duplicada)', () {
    test('mesmos dados com id diferente geram a mesma chave lógica', () {
      final a = _buildRecord(id: 'uuid-1', status: InspectionRecord.statusDraft);
      final b = _buildRecord(id: 'uuid-2', status: InspectionRecord.statusDraft);

      expect(
        a.logicalBusinessKey(),
        equals(b.logicalBusinessKey()),
        reason:
            'Mesma obra/torre/local/fvs/data deveriam colidir na mesma chave, '
            'mesmo com id técnico diferente — é isso que evita duplicar a FVS '
            'quando o usuário reabre um rascunho ou o sync roda duas vezes.',
      );
    });

    test('variação de maiúsculas/minúsculas e espaços não muda a chave', () {
      final a = _buildRecord(id: 'uuid-1', status: InspectionRecord.statusDraft, torre: 'Paris');
      final b = _buildRecord(
        id: 'uuid-2',
        status: InspectionRecord.statusDraft,
        torre: '  paris  ',
      );

      expect(a.logicalBusinessKey(), equals(b.logicalBusinessKey()));
    });

    test('localRef tem prioridade sobre apto quando presente', () {
      final withLocalRef = _buildRecord(
        id: 'uuid-1',
        status: InspectionRecord.statusDraft,
        apto: '501',
        localRef: 'AREA_COMUM',
      );
      final withoutLocalRef = _buildRecord(
        id: 'uuid-2',
        status: InspectionRecord.statusDraft,
        apto: '501',
      );

      expect(
        withLocalRef.logicalBusinessKey(),
        isNot(equals(withoutLocalRef.logicalBusinessKey())),
        reason: 'localRef preenchido deve substituir apto na chave, não somar.',
      );
    });

    test('projectId diferente isola a chave (multi-obra)', () {
      final obraA = _buildRecord(id: 'uuid-1', status: InspectionRecord.statusDraft, projectId: 'obra_a');
      final obraB = _buildRecord(id: 'uuid-2', status: InspectionRecord.statusDraft, projectId: 'obra_b');

      expect(obraA.logicalBusinessKey(), isNot(equals(obraB.logicalBusinessKey())));
    });

    test('operationalSheetId diferente gera chaves diferentes', () {
      final sheet1 = _buildRecord(
        id: 'uuid-1',
        status: InspectionRecord.statusDraft,
        operationalSheetId: 'sheet_1',
      );
      final sheet2 = _buildRecord(
        id: 'uuid-2',
        status: InspectionRecord.statusDraft,
        operationalSheetId: 'sheet_2',
      );

      expect(sheet1.logicalBusinessKey(), isNot(equals(sheet2.logicalBusinessKey())));
    });

    test('dias diferentes de businessDate geram chaves diferentes', () {
      final day1 = _buildRecord(
        id: 'uuid-1',
        status: InspectionRecord.statusDraft,
        createdAt: DateTime(2026, 7, 17, 8, 0),
      );
      final day2 = _buildRecord(
        id: 'uuid-2',
        status: InspectionRecord.statusDraft,
        createdAt: DateTime(2026, 7, 18, 8, 0),
      );

      expect(day1.logicalBusinessKey(), isNot(equals(day2.logicalBusinessKey())));
    });

    test('mesmo dia com horários diferentes gera a mesma chave', () {
      final morning = _buildRecord(
        id: 'uuid-1',
        status: InspectionRecord.statusDraft,
        createdAt: DateTime(2026, 7, 17, 8, 0),
      );
      final evening = _buildRecord(
        id: 'uuid-2',
        status: InspectionRecord.statusDraft,
        createdAt: DateTime(2026, 7, 17, 19, 45),
      );

      expect(morning.logicalBusinessKey(), equals(evening.logicalBusinessKey()));
    });

    test('registro finalizado usa finalizedAt, não createdAt, no dia da chave', () {
      final finalized = _buildRecord(
        id: 'uuid-1',
        status: InspectionRecord.statusFinal,
        createdAt: DateTime(2026, 7, 10, 8, 0),
        finalizedAt: DateTime(2026, 7, 17, 9, 0),
      );
      final draftSameDayAsFinalization = _buildRecord(
        id: 'uuid-2',
        status: InspectionRecord.statusDraft,
        createdAt: DateTime(2026, 7, 17, 8, 0),
      );

      expect(
        finalized.logicalBusinessKey(),
        equals(draftSameDayAsFinalization.logicalBusinessKey()),
        reason:
            'businessDate de um registro final é finalizedAt (não createdAt) — '
            'ver InspectionRecord.businessDate.',
      );
    });
  });
}
