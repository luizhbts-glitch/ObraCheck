import 'package:flutter_test/flutter_test.dart';
import 'package:obra_check/utils/text_case.dart';

void main() {
  group('toSentenceCase', () {
    test('primeira letra maiúscula, resto minúsculo', () {
      expect(toSentenceCase('LIXADEIRA ANGULAR'), 'Lixadeira angular');
      expect(toSentenceCase('lixadeira angular'), 'Lixadeira angular');
      expect(toSentenceCase('lixadeira ANGULAR'), 'Lixadeira angular');
    });

    test('colapsa espaços duplicados e remove das bordas', () {
      expect(toSentenceCase('  lixadeira   angular  '), 'Lixadeira angular');
    });

    test('string vazia continua vazia', () {
      expect(toSentenceCase(''), '');
      expect(toSentenceCase('   '), '');
    });
  });
}
