import '../models/pedido_compra_record.dart';
import '../models/requisicao_compra_record.dart';

/// Status "de exibição" do fluxo de Compras — quadro Kanban confirmado
/// contra a ferramenta pessoal do usuário em 2026-07-18 (ver nota
/// "Referência L7" no Obsidian). É calculado a partir do estado real da
/// Requisição/Pedido, não é um campo próprio gravado em nenhum record.
class KanbanStatusCompra {
  static const String naoAprovada = 'Não aprovada';
  static const String aprovacao = 'Aprovação';
  static const String cotacao = 'Cotação';
  static const String ocEmitida = 'OC Emitida';
  static const String chegadaParcial = 'Chegada parcial';
  static const String finalizado = 'Finalizado';

  static const List<String> ordem = [
    aprovacao,
    cotacao,
    ocEmitida,
    chegadaParcial,
    finalizado,
  ];
}

/// Calcula o status Kanban de uma requisição, considerando o pedido de
/// compra vinculado (se já existir). Mesma regra de precedência vista na
/// ferramenta de referência: pedido cancelado é ignorado (a requisição
/// volta a valer pelo próprio status), rejeitada sempre vence.
String calcularStatusKanbanCompra({
  required RequisicaoCompraRecord requisicao,
  PedidoCompraRecord? pedido,
}) {
  if (requisicao.status == StatusRequisicao.rejeitada) {
    return KanbanStatusCompra.naoAprovada;
  }

  final pedidoValido = pedido != null &&
      !pedido.deleted &&
      pedido.status != StatusPedidoCompra.cancelado;

  if (pedidoValido) {
    switch (pedido.status) {
      case StatusPedidoCompra.recebidoParcial:
        return KanbanStatusCompra.chegadaParcial;
      case StatusPedidoCompra.recebidoTotal:
        return KanbanStatusCompra.finalizado;
      default:
        return KanbanStatusCompra.ocEmitida;
    }
  }

  if (requisicao.status == StatusRequisicao.emCotacao) {
    return KanbanStatusCompra.cotacao;
  }

  return KanbanStatusCompra.aprovacao;
}

/// Gera o próximo código sequencial pra um prefixo (ex.: 'REQ', 'COT',
/// 'OC'), a partir dos códigos já existentes no mesmo escopo (obra).
///
/// Limitação conhecida: em uso offline por mais de um dispositivo ao
/// mesmo tempo, dois pedidos podem nascer com o mesmo número antes de
/// sincronizar (mesma classe de risco que qualquer contador sequencial
/// offline-first). Como o código aqui é só rótulo de rastreio — não é
/// chave de negócio, não decide duplicidade de dado como o
/// `logicalBusinessKey()` do FVS — o risco é aceitável por ora. Revisitar
/// se isso incomodar na prática.
String proximoCodigoSequencial({
  required String prefixo,
  required Iterable<String> codigosExistentes,
  int digitos = 4,
}) {
  final regex = RegExp('^${RegExp.escape(prefixo)}-(\\d+)\$');
  var maior = 0;
  for (final codigo in codigosExistentes) {
    final match = regex.firstMatch(codigo);
    if (match == null) continue;
    final numero = int.tryParse(match.group(1) ?? '') ?? 0;
    if (numero > maior) maior = numero;
  }
  final proximo = maior + 1;
  return '$prefixo-${proximo.toString().padLeft(digitos, '0')}';
}
