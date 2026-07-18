import 'package:flutter_test/flutter_test.dart';
import 'package:obra_check/data/fvs_catalog.dart';
import 'package:obra_check/data/inspection_element_catalog.dart';
import 'package:obra_check/screens/select_fvs_screen.dart';

void main() {
  FvsTemplate byCode(String code) => FvsCatalog.all.firstWhere((t) => t.codigo == code);

  group('SelectFvsResult - contrato de seleção', () {
    test('FVS com regra de elemento permite resultado com elemento preenchido', () {
      final template = byCode('3.2');
      expect(InspectionElementCatalog.requiresElement(template), isTrue);

      const result = SelectFvsResult(
        template: FvsTemplate(
          codigo: '3.2',
          nome: 'Montagem de armaduras',
          profissao: 'Armador',
          itens: [],
        ),
        inspectionElement: 'Pilar',
      );

      expect(result.inspectionElement, 'Pilar');
      expect(result.template.codigo, '3.2');
    });

    test('FVS sem regra de elemento mantém resultado com elemento vazio', () {
      final template = byCode('4.4');
      expect(InspectionElementCatalog.requiresElement(template), isFalse);

      const result = SelectFvsResult(
        template: FvsTemplate(
          codigo: '4.4',
          nome: 'Execução de revestimento cerâmico interno',
          profissao: 'Pedreiro de Acabamento',
          itens: [],
        ),
        inspectionElement: '',
      );

      expect(result.inspectionElement, isEmpty);
      expect(result.template.codigo, '4.4');
    });
  });
}

