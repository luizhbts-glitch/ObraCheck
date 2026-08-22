import 'package:flutter_test/flutter_test.dart';
import 'package:obra_check/models/equipamento_estoque_record.dart';
import 'package:obra_check/utils/equipamento_estoque_rules.dart';

void main() {
  group('validarCamposEquipamentoEstoque — próprio', () {
    test('só exige material', () {
      expect(
        validarCamposEquipamentoEstoque(
          tipo: TipoEquipamentoEstoque.proprio,
          material: 'Furadeira',
        ),
        isNull,
      );
    });

    test('rejeita material vazio', () {
      expect(
        validarCamposEquipamentoEstoque(tipo: TipoEquipamentoEstoque.proprio, material: '  '),
        isNotNull,
      );
    });
  });

  group('validarCamposEquipamentoEstoque — de terceiro', () {
    test('exige material e nome do terceiro', () {
      expect(
        validarCamposEquipamentoEstoque(
          tipo: TipoEquipamentoEstoque.terceiro,
          material: 'Betoneira',
          terceiroNome: '',
        ),
        isNotNull,
      );
      expect(
        validarCamposEquipamentoEstoque(
          tipo: TipoEquipamentoEstoque.terceiro,
          material: 'Betoneira',
          terceiroNome: 'Empreiteira XYZ',
        ),
        isNull,
      );
    });
  });

  group('validarCamposEquipamentoEstoque — alugado', () {
    test('exige todos os campos', () {
      expect(
        validarCamposEquipamentoEstoque(
          tipo: TipoEquipamentoEstoque.alugado,
          material: 'Compactador de solo',
        ),
        isNotNull,
      );
    });

    test('rejeita fim antes do início', () {
      expect(
        validarCamposEquipamentoEstoque(
          tipo: TipoEquipamentoEstoque.alugado,
          material: 'Compactador de solo',
          periodoInicio: DateTime(2026, 8, 10),
          periodoFim: DateTime(2026, 8, 1),
          locadora: 'Locadora X',
          centroCusto: 'Obra Sabiá',
          valor: 500,
        ),
        isNotNull,
      );
    });

    test('rejeita valor zero ou negativo', () {
      expect(
        validarCamposEquipamentoEstoque(
          tipo: TipoEquipamentoEstoque.alugado,
          material: 'Compactador de solo',
          periodoInicio: DateTime(2026, 8, 1),
          periodoFim: DateTime(2026, 8, 10),
          locadora: 'Locadora X',
          centroCusto: 'Obra Sabiá',
          valor: 0,
        ),
        isNotNull,
      );
    });

    test('aceita quando todos os campos estão preenchidos corretamente', () {
      expect(
        validarCamposEquipamentoEstoque(
          tipo: TipoEquipamentoEstoque.alugado,
          material: 'Compactador de solo',
          periodoInicio: DateTime(2026, 8, 1),
          periodoFim: DateTime(2026, 8, 10),
          locadora: 'Locadora X',
          centroCusto: 'Obra Sabiá',
          valor: 500,
        ),
        isNull,
      );
    });
  });
}
