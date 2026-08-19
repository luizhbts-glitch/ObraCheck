import 'package:flutter_test/flutter_test.dart';
import 'package:obra_check/models/centro_custo_record.dart';
import 'package:obra_check/models/cotacao_record.dart';
import 'package:obra_check/models/fornecedor_record.dart';
import 'package:obra_check/models/material_catalogo_record.dart';
import 'package:obra_check/models/pedido_compra_record.dart';
import 'package:obra_check/models/requisicao_compra_record.dart';

void main() {
  group('FornecedorRecord', () {
    test('toMap/fromMap preserva os dados', () {
      final original = FornecedorRecord(
        id: 'f-1',
        orgId: 'org-1',
        nome: 'Cimentos Show',
        cnpj: '00.000.000/0001-00',
        categoria: 'Cimento',
        telefone: '(34) 3000-0000',
        createdAt: DateTime(2026, 7, 19),
        updatedAt: DateTime(2026, 7, 19),
      );

      final restored = FornecedorRecord.fromMap(original.toMap());

      expect(restored.nome, 'Cimentos Show');
      expect(restored.categoria, 'Cimento');
      expect(restored.isActive, true);
    });
  });

  group('MaterialCatalogoRecord', () {
    test('toMap/fromMap preserva os dados, incluindo datas opcionais', () {
      final original = MaterialCatalogoRecord(
        id: 'm-1',
        orgId: 'org-1',
        categoria: 'Material Elétrico',
        produto: 'Disjuntor',
        unidadeMedida: 'UN',
        custoMedioReferencia: 42.5,
        ultimaCompraEm: DateTime(2026, 7, 1),
        createdAt: DateTime(2026, 7, 19),
        updatedAt: DateTime(2026, 7, 19),
      );

      final restored = MaterialCatalogoRecord.fromMap(original.toMap());

      expect(restored.produto, 'Disjuntor');
      expect(restored.custoMedioReferencia, 42.5);
      expect(restored.ultimaCompraEm, DateTime(2026, 7, 1));
    });

    test('sem última compra ainda: campo fica nulo', () {
      final restored = MaterialCatalogoRecord.fromMap(const {
        'id': 'm-2',
        'produto': 'Item novo',
      });
      expect(restored.ultimaCompraEm, isNull);
      expect(restored.custoMedioReferencia, isNull);
    });
  });

  group('CentroCustoRecord', () {
    test('codigoNome combina código e nome', () {
      final centro = CentroCustoRecord(
        id: 'cc-1',
        projectId: 'obra-1',
        codigo: '1.7',
        nome: 'Instalações elétricas',
        createdAt: DateTime(2026, 7, 19),
        updatedAt: DateTime(2026, 7, 19),
      );
      expect(centro.codigoNome, '1.7 - Instalações elétricas');
    });

    test('toMap/fromMap preserva orçado', () {
      final original = CentroCustoRecord(
        id: 'cc-2',
        projectId: 'obra-1',
        codigo: '1.9',
        nome: 'Regularizações',
        orcado: 50000,
        createdAt: DateTime(2026, 7, 19),
        updatedAt: DateTime(2026, 7, 19),
      );
      final restored = CentroCustoRecord.fromMap(original.toMap());
      expect(restored.orcado, 50000);
    });
  });

  group('RequisicaoCompraRecord', () {
    test('toMap/fromMap preserva itens e status', () {
      final original = RequisicaoCompraRecord(
        id: 'r-1',
        codigo: 'REQ-0001',
        projectId: 'obra-1',
        centroCustoId: 'cc-1',
        solicitanteEmployeeId: 'e-1',
        itens: const [
          ItemRequisicao(descricao: 'Cimento CP-II', quantidade: '50', unidade: 'saco'),
        ],
        urgencia: 'urgente',
        status: StatusRequisicao.emCotacao,
        createdAt: DateTime(2026, 7, 19),
        updatedAt: DateTime(2026, 7, 19),
      );

      final restored = RequisicaoCompraRecord.fromMap(original.toMap());

      expect(restored.codigo, 'REQ-0001');
      expect(restored.status, StatusRequisicao.emCotacao);
      expect(restored.itens, hasLength(1));
      expect(restored.itens.first.descricao, 'Cimento CP-II');
    });

    test('sem itens: lista vazia, não quebra', () {
      final restored = RequisicaoCompraRecord.fromMap(const {
        'id': 'r-2',
        'codigo': 'REQ-0002',
      });
      expect(restored.itens, isEmpty);
      expect(restored.status, StatusRequisicao.aberta);
    });
  });

  group('CotacaoRecord', () {
    test('valorTotal soma itens + frete - desconto', () {
      final cotacao = CotacaoRecord(
        id: 'cot-1',
        codigo: 'COT-0001',
        requisicaoId: 'r-1',
        fornecedorId: 'f-1',
        itens: const [
          ItemCotacao(descricao: 'Cimento', quantidade: '50', valorUnitario: 30.0),
        ],
        frete: 100,
        desconto: 50,
        createdAt: DateTime(2026, 7, 19),
        updatedAt: DateTime(2026, 7, 19),
      );

      // subtotal = 50 * 30 = 1500; total = 1500 + 100 - 50 = 1550
      expect(cotacao.subtotal, 1500);
      expect(cotacao.valorTotal, 1550);
    });

    test('toMap/fromMap preserva itens e flag vencedora', () {
      final original = CotacaoRecord(
        id: 'cot-2',
        codigo: 'COT-0002',
        requisicaoId: 'r-1',
        fornecedorId: 'f-2',
        itens: const [
          ItemCotacao(descricao: 'Areia', quantidade: '10', unidade: 'm3', valorUnitario: 80.0),
        ],
        vencedora: true,
        createdAt: DateTime(2026, 7, 19),
        updatedAt: DateTime(2026, 7, 19),
      );

      final restored = CotacaoRecord.fromMap(original.toMap());

      expect(restored.vencedora, true);
      expect(restored.itens.first.valorUnitario, 80.0);
    });
  });

  group('PedidoCompraRecord', () {
    test('saldoAtual assume valorTotal quando não informado (pedido novo)', () {
      final pedido = PedidoCompraRecord(
        id: 'p-1',
        codigo: 'OC-0001',
        requisicaoId: 'r-1',
        fornecedorId: 'f-1',
        projectId: 'obra-1',
        valorTotal: 1550,
        createdAt: DateTime(2026, 7, 19),
        updatedAt: DateTime(2026, 7, 19),
      );
      expect(pedido.saldoAtual, 1550);
    });

    test('entrega parcial: saldoAtual decrementa sem afetar valorTotal', () {
      final pedido = PedidoCompraRecord(
        id: 'p-2',
        codigo: 'OC-0002',
        requisicaoId: 'r-1',
        fornecedorId: 'f-1',
        projectId: 'obra-1',
        valorTotal: 1000,
        saldoAtual: 400,
        status: StatusPedidoCompra.recebidoParcial,
        createdAt: DateTime(2026, 7, 19),
        updatedAt: DateTime(2026, 7, 19),
      );

      final restored = PedidoCompraRecord.fromMap(pedido.toMap());

      expect(restored.valorTotal, 1000);
      expect(restored.saldoAtual, 400);
      expect(restored.status, StatusPedidoCompra.recebidoParcial);
    });

    test('código imutável sobrevive ida e volta pelo Firestore', () {
      final original = PedidoCompraRecord(
        id: 'p-3',
        codigo: 'OC-0003',
        requisicaoId: 'r-1',
        fornecedorId: 'f-1',
        projectId: 'obra-1',
        valorTotal: 500,
        createdAt: DateTime(2026, 7, 19),
        updatedAt: DateTime(2026, 7, 19),
      );
      final restored = PedidoCompraRecord.fromMap(original.toMap());
      expect(restored.codigo, 'OC-0003');
    });
  });
}
