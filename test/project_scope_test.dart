import 'package:flutter_test/flutter_test.dart';
import 'package:obra_check/models/inspection_record.dart';
import 'package:obra_check/utils/project_scope.dart';

void main() {
  group('project_scope', () {
    test('matchesActiveProject bloqueia registros de outra obra', () {
      expect(
        matchesActiveProject(
          activeProjectId: 'obra_a',
          recordProjectId: 'obra_b',
        ),
        isFalse,
      );

      expect(
        matchesActiveProject(
          activeProjectId: 'obra_a',
          recordProjectId: 'obra_a',
        ),
        isTrue,
      );
    });

    test('buildInspectionDraftKey inclui projectId', () {
      final key = buildInspectionDraftKey(
        projectId: 'obra_a',
        obra: 'Obra A',
        torre: 'Paris',
        andar: '5',
        localRef: 'APTO_501',
        fvsCodigo: '4.1',
        inspectionElement: InspectionRecord.inspectionElementKey('Pilar'),
        operationalSheetId: 'sheet_1',
      );

      expect(key.startsWith('draft:obra_a:'), isTrue);
      expect(key.contains(':Paris:5:APTO_501:4.1:'), isTrue);
    });

    test('buildInspectionLegacyDraftKey mantém compatibilidade', () {
      final legacy = buildInspectionLegacyDraftKey(
        obra: 'Obra Legada',
        torre: 'Viena',
        andar: '7',
        localRef: 'APTO_701',
        fvsCodigo: '5.2',
      );

      expect(legacy, 'draft:Obra Legada:Viena:7:APTO_701:5.2');
    });
  });
}
