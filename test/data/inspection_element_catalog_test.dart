import 'package:flutter_test/flutter_test.dart';
import 'package:obra_check/data/fvs_catalog.dart';
import 'package:obra_check/data/inspection_element_catalog.dart';

void main() {
  FvsTemplate byCode(String code) {
    return FvsCatalog.all.firstWhere((t) => t.codigo == code);
  }

  group('InspectionElementCatalog - regra declarativa por código', () {
    test('FVS estrutural exige elemento e retorna opções esperadas', () {
      final template = byCode('3.3');

      final requires = InspectionElementCatalog.requiresElement(template);
      final options = InspectionElementCatalog.elementsFor(template);

      expect(requires, isTrue);
      expect(options, containsAll(['Pilar', 'Viga', 'Laje']));
      expect(options.length, greaterThanOrEqualTo(6));
    });

    test('FVS não estrutural não exige elemento', () {
      final template = byCode('4.2');

      final requires = InspectionElementCatalog.requiresElement(template);
      final options = InspectionElementCatalog.elementsFor(template);

      expect(requires, isFalse);
      expect(options, isEmpty);
    });

    test('catálogo possui regra explícita para todos os códigos do FvsCatalog', () {
      for (final template in FvsCatalog.all) {
        final rule = InspectionElementCatalog.ruleFor(template);
        expect(rule, isNotNull, reason: 'FVS ${template.codigo} sem regra declarativa explícita');
      }
    });
  });
}

