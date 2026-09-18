import 'package:flutter_test/flutter_test.dart';
import 'package:obra_check/utils/insumo_rules.dart';

void main() {
  group('validarNovoInsumo', () {
    test('aceita só com material preenchido', () {
      expect(validarNovoInsumo(material: 'Bloco de espuma', estoqueMinimo: 0), isNull);
    });

    test('rejeita material vazio', () {
      expect(validarNovoInsumo(material: '  ', estoqueMinimo: 0), isNotNull);
    });

    test('rejeita estoque mínimo negativo', () {
      expect(validarNovoInsumo(material: 'Cimento', estoqueMinimo: -1), isNotNull);
    });

    test('rejeita estoque inicial negativo', () {
      expect(
        validarNovoInsumo(material: 'Cimento', estoqueMinimo: 0, quantidadeInicial: -5),
        isNotNull,
      );
    });
  });

  group('validarRetiradaInsumo', () {
    test('aceita retirada dentro do estoque disponível', () {
      expect(
        validarRetiradaInsumo(quantidadeAtual: 10, quantidadeRetirada: 2),
        isNull,
      );
    });

    test('rejeita retirada zero ou negativa', () {
      expect(validarRetiradaInsumo(quantidadeAtual: 10, quantidadeRetirada: 0), isNotNull);
      expect(validarRetiradaInsumo(quantidadeAtual: 10, quantidadeRetirada: -1), isNotNull);
    });

    test('rejeita retirada maior que o estoque atual', () {
      expect(validarRetiradaInsumo(quantidadeAtual: 1, quantidadeRetirada: 2), isNotNull);
    });

    test('aceita retirada que zera exatamente o estoque', () {
      expect(validarRetiradaInsumo(quantidadeAtual: 3, quantidadeRetirada: 3), isNull);
    });
  });

  group('calcularDivergenciaConferencia', () {
    test('positiva quando conferido é maior que esperado (sobra)', () {
      expect(
        calcularDivergenciaConferencia(quantidadeEsperada: 23, quantidadeConferida: 25),
        2,
      );
    });

    test('negativa quando conferido é menor que esperado (furo)', () {
      expect(
        calcularDivergenciaConferencia(quantidadeEsperada: 23, quantidadeConferida: 20),
        -3,
      );
    });

    test('zero quando bate certinho', () {
      expect(
        calcularDivergenciaConferencia(quantidadeEsperada: 23, quantidadeConferida: 23),
        0,
      );
    });
  });

  group('validarConferenciaInsumo', () {
    test('aceita sem observação quando não há divergência', () {
      expect(
        validarConferenciaInsumo(quantidadeConferida: 23, divergencia: 0),
        isNull,
      );
    });

    test('exige observação quando há divergência', () {
      expect(
        validarConferenciaInsumo(quantidadeConferida: 20, divergencia: -3),
        isNotNull,
      );
      expect(
        validarConferenciaInsumo(
          quantidadeConferida: 20,
          divergencia: -3,
          observacao: '  ',
        ),
        isNotNull,
      );
    });

    test('aceita divergência com observação preenchida', () {
      expect(
        validarConferenciaInsumo(
          quantidadeConferida: 20,
          divergencia: -3,
          observacao: 'Estava de atestado, outra pessoa cobriu.',
        ),
        isNull,
      );
    });

    test('rejeita quantidade negativa', () {
      expect(
        validarConferenciaInsumo(quantidadeConferida: -1, divergencia: -24),
        isNotNull,
      );
    });
  });
}
