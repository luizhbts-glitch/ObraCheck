import 'package:flutter_test/flutter_test.dart';
import 'package:obra_check/utils/despesas_rules.dart';

void main() {
  group('nivelPermiteAprovarDespesa', () {
    test('Diretor, TI, Coordenador e Engenheiro (níveis 1-4) aprovam', () {
      for (final nivel in [1, 2, 3, 4]) {
        expect(nivelPermiteAprovarDespesa(nivel), true, reason: 'nível $nivel');
      }
    });

    test('Auxiliar/Administrativo/Comercial e Estagiário (níveis 5-6) não aprovam', () {
      for (final nivel in [5, 6]) {
        expect(nivelPermiteAprovarDespesa(nivel), false, reason: 'nível $nivel');
      }
    });
  });
}
