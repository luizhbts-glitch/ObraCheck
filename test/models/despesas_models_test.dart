import 'package:flutter_test/flutter_test.dart';
import 'package:obra_check/data/fvs_data.dart';
import 'package:obra_check/models/descritivo_servico_record.dart';
import 'package:obra_check/models/despesa_record.dart';
import 'package:obra_check/models/medicao_empreiteiro_record.dart';
import 'package:obra_check/models/orcamento_servico_record.dart';
import 'package:obra_check/models/recebimento_material_record.dart';

void main() {
  group('DescritivoServicoRecord', () {
    test('toMap/fromMap preserva os dados', () {
      final original = DescritivoServicoRecord(
        id: 'ds-1',
        orgId: 'org-1',
        descricao: 'Alvenaria de vedação',
        unidadeMedida: 'm²',
        valorUnitarioReferencia: 45.5,
        createdAt: DateTime(2026, 7, 19),
        updatedAt: DateTime(2026, 7, 19),
      );
      final restored = DescritivoServicoRecord.fromMap(original.toMap());
      expect(restored.descricao, 'Alvenaria de vedação');
      expect(restored.valorUnitarioReferencia, 45.5);
    });
  });

  group('OrcamentoServicoRecord', () {
    test('valorTotalOrcamento soma quantidade x valor unitário de cada item', () {
      final orcamento = OrcamentoServicoRecord(
        id: 'orc-1',
        projectId: 'obra-1',
        empreiteiroId: 'emp-1',
        itens: const [
          ItemOrcamento(descritivoServicoId: 'ds-1', quantidadeOrcada: 100, valorUnitario: 45.5),
          ItemOrcamento(descritivoServicoId: 'ds-2', quantidadeOrcada: 20, valorUnitario: 10),
        ],
        createdAt: DateTime(2026, 7, 19),
        updatedAt: DateTime(2026, 7, 19),
      );
      // 100*45.5 + 20*10 = 4550 + 200 = 4750
      expect(orcamento.valorTotalOrcamento, 4750);
    });

    test('toMap/fromMap preserva itens', () {
      final original = OrcamentoServicoRecord(
        id: 'orc-2',
        projectId: 'obra-1',
        empreiteiroId: 'emp-1',
        itens: const [
          ItemOrcamento(descritivoServicoId: 'ds-1', quantidadeOrcada: 10, valorUnitario: 5),
        ],
        createdAt: DateTime(2026, 7, 19),
        updatedAt: DateTime(2026, 7, 19),
      );
      final restored = OrcamentoServicoRecord.fromMap(original.toMap());
      expect(restored.itens, hasLength(1));
      expect(restored.itens.first.quantidadeOrcada, 10);
    });
  });

  group('MedicaoEmpreiteiroRecord', () {
    test('valorLiquidoAPagar = bruto - adiantamento - imposto - comercial', () {
      final medicao = MedicaoEmpreiteiroRecord(
        id: 'med-1',
        codigo: 'MED-0001',
        orcamentoServicoId: 'orc-1',
        empreiteiroId: 'emp-1',
        projectId: 'obra-1',
        periodo: '2026-07',
        itens: const [
          ItemMedicao(descritivoServicoId: 'ds-1', quantidadeMedida: 50, valorUnitario: 45.5),
        ],
        adiantamentoDeduzido: 500,
        descontoImposto: 227.5,
        descontoComercial: 100,
        createdAt: DateTime(2026, 7, 19),
        updatedAt: DateTime(2026, 7, 19),
      );

      // bruto = 50 * 45.5 = 2275
      expect(medicao.valorBrutoMedido, 2275);
      // líquido = 2275 - 500 - 227.5 - 100 = 1447.5
      expect(medicao.valorLiquidoAPagar, 1447.5);
    });

    test('toMap/fromMap preserva código e status', () {
      final original = MedicaoEmpreiteiroRecord(
        id: 'med-2',
        codigo: 'MED-0002',
        orcamentoServicoId: 'orc-1',
        empreiteiroId: 'emp-1',
        projectId: 'obra-1',
        periodo: '2026-08',
        status: StatusMedicao.aprovada,
        createdAt: DateTime(2026, 7, 19),
        updatedAt: DateTime(2026, 7, 19),
      );
      final restored = MedicaoEmpreiteiroRecord.fromMap(original.toMap());
      expect(restored.codigo, 'MED-0002');
      expect(restored.status, StatusMedicao.aprovada);
    });
  });

  group('RecebimentoMaterialRecord', () {
    test('temProblema é falso quando tudo ok', () {
      final recebimento = RecebimentoMaterialRecord(
        id: 'rec-1',
        pedidoCompraId: 'p-1',
        fornecedorId: 'f-1',
        dataRecebimento: DateTime(2026, 7, 19),
        itensVerificados: const [
          ItemRecebimentoVerificado(descricao: 'Bloco estrutural', status: 'ok'),
        ],
        createdAt: DateTime(2026, 7, 19),
        updatedAt: DateTime(2026, 7, 19),
      );
      expect(recebimento.temProblema, false);
    });

    test('temProblema é true quando prazo falhou', () {
      final recebimento = RecebimentoMaterialRecord(
        id: 'rec-2',
        pedidoCompraId: 'p-1',
        fornecedorId: 'f-1',
        dataRecebimento: DateTime(2026, 7, 19),
        prazoOk: false,
        createdAt: DateTime(2026, 7, 19),
        updatedAt: DateTime(2026, 7, 19),
      );
      expect(recebimento.temProblema, true);
    });

    test('temProblema é true quando um item verificado está nok', () {
      final recebimento = RecebimentoMaterialRecord(
        id: 'rec-3',
        pedidoCompraId: 'p-1',
        fornecedorId: 'f-1',
        dataRecebimento: DateTime(2026, 7, 19),
        itensVerificados: const [
          ItemRecebimentoVerificado(
            descricao: 'Bloco estrutural',
            proofType: FvsProofType.technicalNote,
            status: 'nok',
            obs: 'Sem certificado de carga',
          ),
        ],
        createdAt: DateTime(2026, 7, 19),
        updatedAt: DateTime(2026, 7, 19),
      );
      expect(recebimento.temProblema, true);
    });

    test('toMap/fromMap preserva proofType e certificado', () {
      final original = RecebimentoMaterialRecord(
        id: 'rec-4',
        pedidoCompraId: 'p-1',
        fornecedorId: 'f-1',
        dataRecebimento: DateTime(2026, 7, 19),
        itensVerificados: const [
          ItemRecebimentoVerificado(
            descricao: 'Bloco estrutural',
            proofType: FvsProofType.technicalNote,
            certificadoStoragePath: 'recebimentos/rec-4/certificado.pdf',
          ),
        ],
        fotos: const ['recebimentos/rec-4/foto1.jpg'],
        createdAt: DateTime(2026, 7, 19),
        updatedAt: DateTime(2026, 7, 19),
      );
      final restored = RecebimentoMaterialRecord.fromMap(original.toMap());
      expect(restored.itensVerificados.first.proofType, FvsProofType.technicalNote);
      expect(
        restored.itensVerificados.first.certificadoStoragePath,
        'recebimentos/rec-4/certificado.pdf',
      );
      expect(restored.fotos, ['recebimentos/rec-4/foto1.jpg']);
    });
  });

  group('DespesaRecord', () {
    test('toMap/fromMap preserva tipo, origem e vencimento', () {
      final original = DespesaRecord(
        id: 'desp-1',
        codigo: 'DESP-0001',
        projectId: 'obra-1',
        tipo: TipoDespesa.controlada,
        origem: OrigemDespesa.ordemCompra,
        origemId: 'p-1',
        valor: 1550,
        vencimento: DateTime(2026, 8, 1),
        lancadoPorEmployeeId: 'e-1',
        createdAt: DateTime(2026, 7, 19),
        updatedAt: DateTime(2026, 7, 19),
      );
      final restored = DespesaRecord.fromMap(original.toMap());
      expect(restored.tipo, TipoDespesa.controlada);
      expect(restored.origem, OrigemDespesa.ordemCompra);
      expect(restored.vencimento, DateTime(2026, 8, 1));
    });

    test('despesa não controlada não precisa de origemId', () {
      final restored = DespesaRecord.fromMap({
        'id': 'desp-2',
        'codigo': 'DESP-0002',
        'projectId': 'obra-1',
        'tipo': TipoDespesa.naoControlada,
        'origem': OrigemDespesa.avulsa,
        'descricao': 'Frete emergencial',
        'valor': 250.0,
        'lancadoPorEmployeeId': 'e-2',
      });
      expect(restored.origemId, isNull);
      expect(restored.descricao, 'Frete emergencial');
    });

    test('aprovação registra quem e quando', () {
      final despesa = DespesaRecord(
        id: 'desp-3',
        codigo: 'DESP-0003',
        projectId: 'obra-1',
        tipo: TipoDespesa.naoControlada,
        origem: OrigemDespesa.avulsa,
        valor: 500,
        lancadoPorEmployeeId: 'e-1',
        createdAt: DateTime(2026, 7, 19),
        updatedAt: DateTime(2026, 7, 19),
      );
      final aprovada = despesa.copyWith(
        status: StatusDespesa.aprovada,
        aprovadoPorEmployeeId: 'e-4',
        aprovadoEm: DateTime(2026, 7, 20),
      );
      final restored = DespesaRecord.fromMap(aprovada.toMap());
      expect(restored.status, StatusDespesa.aprovada);
      expect(restored.aprovadoPorEmployeeId, 'e-4');
      expect(restored.aprovadoEm, DateTime(2026, 7, 20));
    });
  });
}
