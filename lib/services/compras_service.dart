import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/centro_custo_record.dart';
import '../models/cotacao_record.dart';
import '../models/fornecedor_record.dart';
import '../models/material_catalogo_record.dart';
import '../models/pedido_compra_record.dart';
import '../models/project_record.dart';
import '../models/requisicao_compra_record.dart';
import '../utils/compras_status.dart';

/// Orquestra o fluxo de Compras: Requisição → Cotação → Pedido →
/// Recebimento. Cada escrita salva local (Hive, offline-first) e espelha
/// pro Firestore em melhor esforço — falha de rede nunca bloqueia o
/// lançamento local.
///
/// Nota de permissão: este serviço não checa `PerfilAcesso` — quem chama
/// (a tela) é responsável por checar com `hasErpPermission`/`canGrant`
/// antes, mesmo padrão já usado no resto do app (`PermissionService.ensure`
/// na UI, não dentro do serviço de dados).
class ComprasService {
  ComprasService._();

  static final ComprasService instance = ComprasService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Box<FornecedorRecord> get _fornecedores =>
      Hive.box<FornecedorRecord>('fornecedores');
  Box<MaterialCatalogoRecord> get _materiais =>
      Hive.box<MaterialCatalogoRecord>('materiais_catalogo');
  Box<CentroCustoRecord> get _centrosCusto =>
      Hive.box<CentroCustoRecord>('centros_custo');
  Box<RequisicaoCompraRecord> get _requisicoes =>
      Hive.box<RequisicaoCompraRecord>('requisicoes_compra');
  Box<CotacaoRecord> get _cotacoes => Hive.box<CotacaoRecord>('cotacoes');
  Box<PedidoCompraRecord> get _pedidos =>
      Hive.box<PedidoCompraRecord>('pedidos_compra');
  Box<ProjectRecord> get _projects => Hive.box<ProjectRecord>('projects');

  Future<void> _mirror(String path, Map<String, dynamic> data) async {
    try {
      await _firestore.doc(path).set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[COMPRAS] Falha ao espelhar $path no Firestore: $e');
    }
  }

  // ── Fornecedores ──────────────────────────────────────────────────────

  List<FornecedorRecord> fornecedores(String orgId, {bool onlyActive = true}) {
    final list = _fornecedores.values
        .where((f) => f.orgId == orgId && (!onlyActive || f.isActive))
        .toList()
      ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
    return list;
  }

  Future<FornecedorRecord> criarFornecedor({
    required String orgId,
    required String nome,
    String? cnpj,
    String categoria = '',
    String? telefone,
  }) async {
    final now = DateTime.now();
    final record = FornecedorRecord(
      id: 'forn_${now.microsecondsSinceEpoch}',
      orgId: orgId,
      nome: nome.trim(),
      cnpj: cnpj,
      categoria: categoria.trim(),
      telefone: telefone,
      createdAt: now,
      updatedAt: now,
    );
    await _fornecedores.put(record.id, record);
    await _mirror('construtoras/$orgId/fornecedores/${record.id}', record.toMap());
    return record;
  }

  // ── Materiais (catálogo) ─────────────────────────────────────────────

  List<MaterialCatalogoRecord> materiaisCatalogo(
    String orgId, {
    bool onlyActive = true,
  }) {
    final list = _materiais.values
        .where((m) => m.orgId == orgId && (!onlyActive || m.isActive))
        .toList()
      ..sort((a, b) => a.produto.toLowerCase().compareTo(b.produto.toLowerCase()));
    return list;
  }

  Future<MaterialCatalogoRecord> criarMaterial({
    required String orgId,
    required String produto,
    String categoria = '',
    String unidadeMedida = '',
  }) async {
    final now = DateTime.now();
    final record = MaterialCatalogoRecord(
      id: 'mat_${now.microsecondsSinceEpoch}',
      orgId: orgId,
      categoria: categoria.trim(),
      produto: produto.trim(),
      unidadeMedida: unidadeMedida.trim(),
      createdAt: now,
      updatedAt: now,
    );
    await _materiais.put(record.id, record);
    await _mirror(
      'construtoras/$orgId/materiais_catalogo/${record.id}',
      record.toMap(),
    );
    return record;
  }

  /// Atualiza custo médio de referência + data da última compra — chamado
  /// quando um pedido de compra é aprovado (ver [aprovarPedido]).
  Future<void> _atualizarReferenciaMaterial({
    required String orgId,
    required String materialCatalogoId,
    required double valorUnitario,
  }) async {
    final material = _materiais.get(materialCatalogoId);
    if (material == null) return;
    final atualizado = material.copyWith(
      custoMedioReferencia: valorUnitario,
      ultimaCompraEm: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _materiais.put(atualizado.id, atualizado);
    await _mirror(
      'construtoras/$orgId/materiais_catalogo/${atualizado.id}',
      atualizado.toMap(),
    );
  }

  // ── Centro de custo ───────────────────────────────────────────────────

  List<CentroCustoRecord> centrosCusto(String projectId, {bool onlyActive = true}) {
    final list = _centrosCusto.values
        .where((c) => c.projectId == projectId && (!onlyActive || c.isActive))
        .toList()
      ..sort((a, b) => a.codigo.compareTo(b.codigo));
    return list;
  }

  Future<CentroCustoRecord> criarCentroCusto({
    required String projectId,
    required String codigo,
    required String nome,
    double? orcado,
  }) async {
    final now = DateTime.now();
    final record = CentroCustoRecord(
      id: 'cc_${now.microsecondsSinceEpoch}',
      projectId: projectId,
      codigo: codigo.trim(),
      nome: nome.trim(),
      orcado: orcado,
      createdAt: now,
      updatedAt: now,
    );
    await _centrosCusto.put(record.id, record);
    await _mirror(
      'projects/$projectId/centros_custo/${record.id}',
      record.toMap(),
    );
    return record;
  }

  // ── Requisições ────────────────────────────────────────────────────────

  List<RequisicaoCompraRecord> requisicoes(String projectId) {
    final list = _requisicoes.values
        .where((r) => r.projectId == projectId && !r.deleted)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<RequisicaoCompraRecord> criarRequisicao({
    required String projectId,
    String? centroCustoId,
    required String solicitanteEmployeeId,
    required List<ItemRequisicao> itens,
    String urgencia = 'normal',
    String? observacao,
  }) async {
    final now = DateTime.now();
    final codigo = proximoCodigoSequencial(
      prefixo: 'REQ',
      codigosExistentes: requisicoes(projectId).map((r) => r.codigo),
    );
    final record = RequisicaoCompraRecord(
      id: 'req_${now.microsecondsSinceEpoch}',
      codigo: codigo,
      projectId: projectId,
      centroCustoId: centroCustoId,
      solicitanteEmployeeId: solicitanteEmployeeId,
      itens: itens,
      urgencia: urgencia,
      observacao: observacao,
      pendingSync: true,
      createdAt: now,
      updatedAt: now,
    );
    await _requisicoes.put(record.id, record);
    await _syncRequisicao(record);
    return record;
  }

  Future<void> _syncRequisicao(RequisicaoCompraRecord record) async {
    try {
      await _firestore
          .doc('projects/${record.projectId}/requisicoes_compra/${record.id}')
          .set(record.toMap(), SetOptions(merge: true));
      await _requisicoes.put(
        record.id,
        record.copyWith(pendingSync: false, updatedAt: DateTime.now()),
      );
    } catch (e) {
      debugPrint('[COMPRAS] Falha ao sincronizar requisição ${record.id}: $e');
    }
  }

  Future<void> iniciarCotacao(String requisicaoId) async {
    final requisicao = _requisicoes.get(requisicaoId);
    if (requisicao == null) return;
    final atualizada = requisicao.copyWith(
      status: StatusRequisicao.emCotacao,
      pendingSync: true,
      updatedAt: DateTime.now(),
    );
    await _requisicoes.put(atualizada.id, atualizada);
    await _syncRequisicao(atualizada);
  }

  Future<void> rejeitarRequisicao(String requisicaoId) async {
    final requisicao = _requisicoes.get(requisicaoId);
    if (requisicao == null) return;
    final atualizada = requisicao.copyWith(
      status: StatusRequisicao.rejeitada,
      pendingSync: true,
      updatedAt: DateTime.now(),
    );
    await _requisicoes.put(atualizada.id, atualizada);
    await _syncRequisicao(atualizada);
  }

  // ── Cotações ───────────────────────────────────────────────────────────

  List<CotacaoRecord> cotacoesDaRequisicao(String requisicaoId) {
    final list = _cotacoes.values
        .where((c) => c.requisicaoId == requisicaoId && !c.deleted)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  Future<CotacaoRecord> adicionarCotacao({
    required String requisicaoId,
    required String fornecedorId,
    required List<ItemCotacao> itens,
    double? frete,
    double? desconto,
    String? prazoEntrega,
    String? condicaoPagamento,
  }) async {
    final requisicao = _requisicoes.get(requisicaoId);
    if (requisicao == null) {
      throw StateError('Requisição $requisicaoId não encontrada.');
    }

    final now = DateTime.now();
    final codigo = proximoCodigoSequencial(
      prefixo: 'COT',
      codigosExistentes: _cotacoes.values.map((c) => c.codigo),
    );
    final record = CotacaoRecord(
      id: 'cot_${now.microsecondsSinceEpoch}',
      codigo: codigo,
      requisicaoId: requisicaoId,
      fornecedorId: fornecedorId,
      itens: itens,
      frete: frete,
      desconto: desconto,
      prazoEntrega: prazoEntrega,
      condicaoPagamento: condicaoPagamento,
      pendingSync: true,
      createdAt: now,
      updatedAt: now,
    );
    await _cotacoes.put(record.id, record);
    await _mirror(
      'projects/${requisicao.projectId}/cotacoes/${record.id}',
      record.toMap(),
    );

    // Requisição que ainda estava "aberta" avança pra "em_cotacao"
    // automaticamente ao receber a primeira cotação.
    if (requisicao.status == StatusRequisicao.aberta) {
      await iniciarCotacao(requisicaoId);
    }

    return record;
  }

  /// Marca a cotação vencedora e converte em Pedido de Compra. Desmarca
  /// qualquer outra vencedora da mesma requisição (só pode haver uma).
  Future<PedidoCompraRecord> aprovarCotacao(String cotacaoId) async {
    final cotacao = _cotacoes.get(cotacaoId);
    if (cotacao == null) {
      throw StateError('Cotação $cotacaoId não encontrada.');
    }
    final requisicao = _requisicoes.get(cotacao.requisicaoId);
    if (requisicao == null) {
      throw StateError('Requisição da cotação $cotacaoId não encontrada.');
    }

    for (final outra in cotacoesDaRequisicao(cotacao.requisicaoId)) {
      if (outra.id == cotacao.id || !outra.vencedora) continue;
      final desmarcada = outra.copyWith(vencedora: false, updatedAt: DateTime.now());
      await _cotacoes.put(desmarcada.id, desmarcada);
      await _mirror(
        'projects/${requisicao.projectId}/cotacoes/${desmarcada.id}',
        desmarcada.toMap(),
      );
    }

    final cotacaoVencedora = cotacao.copyWith(vencedora: true, updatedAt: DateTime.now());
    await _cotacoes.put(cotacaoVencedora.id, cotacaoVencedora);
    await _mirror(
      'projects/${requisicao.projectId}/cotacoes/${cotacaoVencedora.id}',
      cotacaoVencedora.toMap(),
    );

    final now = DateTime.now();
    final codigo = proximoCodigoSequencial(
      prefixo: 'OC',
      codigosExistentes: _pedidos.values.map((p) => p.codigo),
    );
    final pedido = PedidoCompraRecord(
      id: 'ped_${now.microsecondsSinceEpoch}',
      codigo: codigo,
      requisicaoId: requisicao.id,
      cotacaoVencedoraId: cotacaoVencedora.id,
      fornecedorId: cotacaoVencedora.fornecedorId,
      projectId: requisicao.projectId,
      centroCustoId: requisicao.centroCustoId,
      valorTotal: cotacaoVencedora.valorTotal,
      prazoEntrega: cotacaoVencedora.prazoEntrega,
      pendingSync: true,
      createdAt: now,
      updatedAt: now,
    );
    await _pedidos.put(pedido.id, pedido);
    await _mirror(
      'projects/${requisicao.projectId}/pedidos_compra/${pedido.id}',
      pedido.toMap(),
    );

    final requisicaoAtualizada = requisicao.copyWith(
      status: StatusRequisicao.virouPedido,
      pendingSync: true,
      updatedAt: now,
    );
    await _requisicoes.put(requisicaoAtualizada.id, requisicaoAtualizada);
    await _syncRequisicao(requisicaoAtualizada);

    return pedido;
  }

  // ── Pedidos de compra ────────────────────────────────────────────────

  List<PedidoCompraRecord> pedidos(String projectId) {
    final list = _pedidos.values
        .where((p) => p.projectId == projectId && !p.deleted)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  PedidoCompraRecord? pedidoDaRequisicao(String requisicaoId) {
    for (final pedido in _pedidos.values) {
      if (pedido.requisicaoId == requisicaoId && !pedido.deleted) return pedido;
    }
    return null;
  }

  Future<void> aprovarPedido({
    required String pedidoId,
    required String aprovadoPorEmployeeId,
  }) async {
    final pedido = _pedidos.get(pedidoId);
    if (pedido == null) return;
    final now = DateTime.now();
    final atualizado = pedido.copyWith(
      status: StatusPedidoCompra.aprovado,
      aprovadoPorEmployeeId: aprovadoPorEmployeeId,
      aprovadoEm: now,
      pendingSync: true,
      updatedAt: now,
    );
    await _pedidos.put(atualizado.id, atualizado);
    await _mirror(
      'projects/${atualizado.projectId}/pedidos_compra/${atualizado.id}',
      atualizado.toMap(),
    );

    final orgId = _projects.get(atualizado.projectId)?.orgId ?? '';
    final cotacao = atualizado.cotacaoVencedoraId != null
        ? _cotacoes.get(atualizado.cotacaoVencedoraId)
        : null;
    if (orgId.isNotEmpty && cotacao != null) {
      for (final item in cotacao.itens) {
        if (item.materialCatalogoId == null) continue;
        await _atualizarReferenciaMaterial(
          orgId: orgId,
          materialCatalogoId: item.materialCatalogoId!,
          valorUnitario: item.valorUnitario,
        );
      }
    }
  }

  /// Registra recebimento (parcial ou total). `valorRecebido` decrementa o
  /// saldo — quando chega a zero (ou menos, por segurança), o pedido vira
  /// `recebido_total`; enquanto sobra saldo, `recebido_parcial`.
  Future<void> registrarRecebimento({
    required String pedidoId,
    required double valorRecebido,
  }) async {
    final pedido = _pedidos.get(pedidoId);
    if (pedido == null) return;
    if (valorRecebido <= 0) return;

    final novoSaldo = (pedido.saldoAtual - valorRecebido).clamp(
      0,
      pedido.valorTotal,
    );
    final status = novoSaldo <= 0
        ? StatusPedidoCompra.recebidoTotal
        : StatusPedidoCompra.recebidoParcial;

    final atualizado = pedido.copyWith(
      saldoAtual: novoSaldo.toDouble(),
      status: status,
      pendingSync: true,
      updatedAt: DateTime.now(),
    );
    await _pedidos.put(atualizado.id, atualizado);
    await _mirror(
      'projects/${atualizado.projectId}/pedidos_compra/${atualizado.id}',
      atualizado.toMap(),
    );
  }

  Future<void> cancelarPedido(String pedidoId) async {
    final pedido = _pedidos.get(pedidoId);
    if (pedido == null) return;
    final atualizado = pedido.copyWith(
      status: StatusPedidoCompra.cancelado,
      pendingSync: true,
      updatedAt: DateTime.now(),
    );
    await _pedidos.put(atualizado.id, atualizado);
    await _mirror(
      'projects/${atualizado.projectId}/pedidos_compra/${atualizado.id}',
      atualizado.toMap(),
    );
  }
}
