import 'package:flutter_test/flutter_test.dart';
import 'package:obra_check/models/inspection_record.dart';

InspectionRecord buildRecord({
  required String id,
  required String fvs,
  required String torre,
  required int andar,
  required String localRef,
  String inspectionElement = '',
  String itemStatus = 'nok',
}) {
  final now = DateTime.now();
  return InspectionRecord(
    id: id,
    obra: 'Arsen Sabiá',
    torre: torre,
    andar: andar,
    apto: localRef.replaceFirst('APTO_', ''),
    localRef: localRef,
    fvsCodigo: fvs,
    fvsNome: 'Teste',
    inspectionElement: inspectionElement,
    itens: [
      InspectionItemResult(
        index: 0,
        descricao: 'Item',
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
    actionByName: 'Nome',
    actionByCargo: 'Cargo',
    actionAt: now,
    deleted: false,
    pendingSync: false,
    deletedAt: null,
    ncCompanyId: null,
    ncCompanyName: null,
  );
}

List<InspectionRecord> filterByElement(
  List<InspectionRecord> input,
  String? selected,
) {
  const withoutElement = '__SEM_ELEMENTO__';
  return input.where((r) {
    if (selected == null) return true;
    final element = r.normalizedInspectionElement;
    if (selected == withoutElement) return element.isEmpty;
    return element == selected;
  }).toList();
}

void main() {
  group('filtros por elemento - relatórios/NC', () {
    final records = <InspectionRecord>[
      buildRecord(
        id: 'a',
        fvs: '3.3',
        torre: 'Paris',
        andar: 4,
        localRef: 'APTO_401',
        inspectionElement: 'Pilar',
      ),
      buildRecord(
        id: 'b',
        fvs: '3.3',
        torre: 'Paris',
        andar: 4,
        localRef: 'APTO_401',
        inspectionElement: 'Viga',
      ),
      buildRecord(
        id: 'c',
        fvs: '4.2',
        torre: 'Paris',
        andar: 4,
        localRef: 'APTO_401',
        inspectionElement: '',
      ),
    ];

    test('filtrar por elemento específico retorna apenas correspondente', () {
      final filtered = filterByElement(records, 'Pilar');
      expect(filtered.map((e) => e.id).toList(), ['a']);
    });

    test('filtrar por sem elemento mantém compatibilidade legada', () {
      final filtered = filterByElement(records, '__SEM_ELEMENTO__');
      expect(filtered.map((e) => e.id).toList(), ['c']);
    });

    test('sem filtro não esconde registros legados nem com elemento', () {
      final filtered = filterByElement(records, null);
      expect(filtered.length, 3);
    });
  });
}

