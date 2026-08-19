import 'package:flutter_test/flutter_test.dart';
import 'package:obra_check/models/pedido_compra_record.dart';
import 'package:obra_check/models/requisicao_compra_record.dart';
import 'package:obra_check/utils/compras_status.dart';

RequisicaoCompraRecord _requisicao(String status) {
  return RequisicaoCompraRecord(
    id: 'r-1',
    codigo: 'REQ-0001',
    projectId: 'obra-1',
    solicitanteEmployeeId: 'e-1',
    status: status,
    createdAt: DateTime(2026, 7, 19),
    updatedAt: DateTime(2026, 7, 19),
  );
}

PedidoCompraRecord _pedido(String status, {bool deleted = false}) {
  return PedidoCompraRecord(
    id: 'p-1',
    codigo: 'OC-0001',
    requisicaoId: 'r-1',
    fornecedorId: 'f-1',
    projectId: 'obra-1',
    valorTotal: 1000,
    status: status,
    deleted: deleted,
    createdAt: DateTime(2026, 7, 19),
    updatedAt: DateTime(2026, 7, 19),
  );
}

void main() {
  group('calcularStatusKanbanCompra', () {
    test('requisição aberta, sem pedido: Aprovação', () {
      final status = calcularStatusKanbanCompra(
        requisicao: _requisicao(StatusRequisicao.aberta),
      );
      expect(status, KanbanStatusCompra.aprovacao);
    });

    test('requisição em cotação, sem pedido: Cotação', () {
      final status = calcularStatusKanbanCompra(
        requisicao: _requisicao(StatusRequisicao.emCotacao),
      );
      expect(status, KanbanStatusCompra.cotacao);
    });

    test('requisição rejeitada: Não aprovada, mesmo com pedido inexistente', () {
      final status = calcularStatusKanbanCompra(
        requisicao: _requisicao(StatusRequisicao.rejeitada),
      );
      expect(status, KanbanStatusCompra.naoAprovada);
    });

    test('pedido pendente/aprovado/enviado: OC Emitida', () {
      for (final statusPedido in [
        StatusPedidoCompra.pendenteAprovacao,
        StatusPedidoCompra.aprovado,
        StatusPedidoCompra.enviado,
      ]) {
        final status = calcularStatusKanbanCompra(
          requisicao: _requisicao(StatusRequisicao.virouPedido),
          pedido: _pedido(statusPedido),
        );
        expect(status, KanbanStatusCompra.ocEmitida, reason: statusPedido);
      }
    });

    test('pedido com entrega parcial: Chegada parcial', () {
      final status = calcularStatusKanbanCompra(
        requisicao: _requisicao(StatusRequisicao.virouPedido),
        pedido: _pedido(StatusPedidoCompra.recebidoParcial),
      );
      expect(status, KanbanStatusCompra.chegadaParcial);
    });

    test('pedido totalmente recebido: Finalizado', () {
      final status = calcularStatusKanbanCompra(
        requisicao: _requisicao(StatusRequisicao.virouPedido),
        pedido: _pedido(StatusPedidoCompra.recebidoTotal),
      );
      expect(status, KanbanStatusCompra.finalizado);
    });

    test('pedido cancelado: ignora o pedido, volta a valer o status da requisição', () {
      final status = calcularStatusKanbanCompra(
        requisicao: _requisicao(StatusRequisicao.emCotacao),
        pedido: _pedido(StatusPedidoCompra.cancelado),
      );
      expect(status, KanbanStatusCompra.cotacao);
    });

    test('pedido com tombstone (deleted): ignora o pedido também', () {
      final status = calcularStatusKanbanCompra(
        requisicao: _requisicao(StatusRequisicao.aberta),
        pedido: _pedido(StatusPedidoCompra.aprovado, deleted: true),
      );
      expect(status, KanbanStatusCompra.aprovacao);
    });
  });

  group('proximoCodigoSequencial', () {
    test('primeiro código da lista vazia começa em 1', () {
      final codigo = proximoCodigoSequencial(
        prefixo: 'REQ',
        codigosExistentes: const [],
      );
      expect(codigo, 'REQ-0001');
    });

    test('continua a partir do maior número existente', () {
      final codigo = proximoCodigoSequencial(
        prefixo: 'REQ',
        codigosExistentes: const ['REQ-0001', 'REQ-0003', 'REQ-0002'],
      );
      expect(codigo, 'REQ-0004');
    });

    test('ignora códigos de outro prefixo', () {
      final codigo = proximoCodigoSequencial(
        prefixo: 'COT',
        codigosExistentes: const ['REQ-0001', 'REQ-0099'],
      );
      expect(codigo, 'COT-0001');
    });

    test('ignora entradas malformadas sem quebrar', () {
      final codigo = proximoCodigoSequencial(
        prefixo: 'OC',
        codigosExistentes: const ['OC-abc', 'lixo', 'OC-0005'],
      );
      expect(codigo, 'OC-0006');
    });
  });
}
