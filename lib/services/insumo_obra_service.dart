import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/insumo_obra_record.dart';

/// Planilha simples de estoque de insumos de obra — separada do fluxo
/// formal de Compras. Mesmo padrão Hive-first/mirror-Firestore-em-melhor-
/// esforço do resto do ERP (`EquipamentoEstoqueService`, `ComprasService`):
/// sem checagem de permissão aqui, quem chama (a tela) é responsável.
class InsumoObraService {
  InsumoObraService._();

  static final InsumoObraService instance = InsumoObraService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Box<InsumoObraRecord> get _insumos => Hive.box<InsumoObraRecord>('insumos_obra');
  Box<InsumoMovimentoRecord> get _movimentos =>
      Hive.box<InsumoMovimentoRecord>('insumos_obra_movimentos');
  Box<InsumoConferenciaRecord> get _conferencias =>
      Hive.box<InsumoConferenciaRecord>('insumos_obra_conferencias');

  Future<void> _mirror(String path, Map<String, dynamic> data) async {
    try {
      await _firestore.doc(path).set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[INSUMO_OBRA] Falha ao espelhar $path no Firestore: $e');
    }
  }

  List<InsumoObraRecord> listar(String projectId) {
    final list = _insumos.values.where((i) => i.projectId == projectId && !i.deleted).toList()
      ..sort((a, b) => a.material.toLowerCase().compareTo(b.material.toLowerCase()));
    return list;
  }

  List<InsumoMovimentoRecord> historico(String projectId, {String? material}) {
    final query = (material ?? '').trim().toLowerCase();
    final list = _movimentos.values
        .where((m) => m.projectId == projectId && !m.deleted)
        .where((m) => query.isEmpty || m.material.toLowerCase().contains(query))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<InsumoObraRecord> criar({
    required String projectId,
    required String material,
    String endereco = '',
    double estoqueMinimo = 0,
    double quantidadeInicial = 0,
    String unidade = UnidadeMedida.unidade,
  }) async {
    final now = DateTime.now();
    final record = InsumoObraRecord(
      id: 'insumo_${now.microsecondsSinceEpoch}',
      projectId: projectId,
      material: material.trim(),
      endereco: endereco.trim(),
      estoqueMinimo: estoqueMinimo,
      quantidadeAtual: quantidadeInicial,
      unidade: unidade,
      pendingSync: true,
      createdAt: now,
      updatedAt: now,
    );
    await _insumos.put(record.id, record);
    await _mirror('projects/$projectId/insumos_obra/${record.id}', record.toMap());
    return record;
  }

  Future<void> editar(
    InsumoObraRecord atual, {
    String? material,
    String? endereco,
    double? estoqueMinimo,
    String? unidade,
  }) async {
    final atualizado = atual.copyWith(
      material: material?.trim(),
      endereco: endereco?.trim(),
      estoqueMinimo: estoqueMinimo,
      unidade: unidade,
      pendingSync: true,
      updatedAt: DateTime.now(),
    );
    await _insumos.put(atualizado.id, atualizado);
    await _mirror(
      'projects/${atualizado.projectId}/insumos_obra/${atualizado.id}',
      atualizado.toMap(),
    );
  }

  Future<void> excluir(InsumoObraRecord record) async {
    final tombstone = record.copyWith(deleted: true, pendingSync: true, updatedAt: DateTime.now());
    await _insumos.put(tombstone.id, tombstone);
    await _mirror(
      'projects/${tombstone.projectId}/insumos_obra/${tombstone.id}',
      tombstone.toMap(),
    );
  }

  /// Ajusta o estoque pra um valor conferido na contagem física — não é
  /// "retirada" nem "entrada", é a fonte da verdade sendo corrigida.
  Future<void> atualizarContagem(InsumoObraRecord insumo, double novaQuantidade) async {
    final agora = DateTime.now();
    final atualizado = insumo.copyWith(
      quantidadeAtual: novaQuantidade,
      pendingSync: true,
      updatedAt: agora,
    );
    await _insumos.put(atualizado.id, atualizado);
    await _mirror(
      'projects/${atualizado.projectId}/insumos_obra/${atualizado.id}',
      atualizado.toMap(),
    );
    await _registrarMovimento(
      insumo: atualizado,
      tipo: TipoMovimentoInsumo.ajusteContagem,
      quantidade: novaQuantidade - insumo.quantidadeAtual,
      createdAt: agora,
    );
  }

  /// Retirada informal: desconta na hora, sem aprovação. Validação de
  /// limites (quantidade positiva, não exceder o estoque) é
  /// responsabilidade de quem chama (`validarRetiradaInsumo`).
  Future<void> retirar(InsumoObraRecord insumo, double quantidade) async {
    final agora = DateTime.now();
    final novaQuantidade = insumo.quantidadeAtual - quantidade;
    final atualizado = insumo.copyWith(
      quantidadeAtual: novaQuantidade,
      pendingSync: true,
      updatedAt: agora,
    );
    await _insumos.put(atualizado.id, atualizado);
    await _mirror(
      'projects/${atualizado.projectId}/insumos_obra/${atualizado.id}',
      atualizado.toMap(),
    );
    await _registrarMovimento(
      insumo: atualizado,
      tipo: TipoMovimentoInsumo.retirada,
      quantidade: quantidade,
      createdAt: agora,
    );
  }

  Future<void> _registrarMovimento({
    required InsumoObraRecord insumo,
    required String tipo,
    required double quantidade,
    required DateTime createdAt,
  }) async {
    final movimento = InsumoMovimentoRecord(
      id: 'insumomov_${createdAt.microsecondsSinceEpoch}',
      projectId: insumo.projectId,
      insumoId: insumo.id,
      material: insumo.material,
      tipo: tipo,
      quantidade: quantidade,
      saldoResultante: insumo.quantidadeAtual,
      pendingSync: true,
      createdAt: createdAt,
    );
    await _movimentos.put(movimento.id, movimento);
    await _mirror(
      'projects/${insumo.projectId}/insumos_obra_movimentos/${movimento.id}',
      movimento.toMap(),
    );
  }

  // ── Conferência (controle, não auditoria) ───────────────────────────
  //
  // Especificado com o usuário em 2026-09-18: todo insumo que teve
  // retirada desde a última conferência (e não foi retirado só hoje —
  // dá um dia pra "amanhã recontar") aparece como pendente. Reconferir
  // resolve TODAS as retiradas pendentes daquele insumo de uma vez — não
  // é um item por dia, é "confere o estoque atual contra o que o
  // sistema acha que tem agora".

  /// Data (sem hora) da última conferência feita pra esse insumo, ou
  /// `null` se nunca foi conferido.
  DateTime? _ultimaConferenciaEm(String insumoId) {
    DateTime? ultima;
    for (final c in _conferencias.values) {
      if (c.insumoId != insumoId || c.deleted) continue;
      if (ultima == null || c.createdAt.isAfter(ultima)) ultima = c.createdAt;
    }
    return ultima;
  }

  /// Insumos com retirada pendente de reconferência — só entram na lista
  /// no dia seguinte à retirada (retiradas de hoje ainda não contam).
  List<PendenciaConferencia> pendenciasDeConferencia(String projectId) {
    final hoje = DateTime.now();
    final inicioDeHoje = DateTime(hoje.year, hoje.month, hoje.day);

    final pendencias = <PendenciaConferencia>[];
    for (final insumo in listar(projectId)) {
      final ultimaConferencia = _ultimaConferenciaEm(insumo.id);
      final retiradasPendentes = _movimentos.values.where((m) =>
          m.insumoId == insumo.id &&
          !m.deleted &&
          m.tipo == TipoMovimentoInsumo.retirada &&
          m.createdAt.isBefore(inicioDeHoje) &&
          (ultimaConferencia == null || m.createdAt.isAfter(ultimaConferencia)));

      if (retiradasPendentes.isEmpty) continue;

      final quantidadeRetiradaPendente =
          retiradasPendentes.fold<double>(0, (total, m) => total + m.quantidade);
      final ultimaRetiradaEm = retiradasPendentes
          .map((m) => m.createdAt)
          .reduce((a, b) => a.isAfter(b) ? a : b);

      pendencias.add(PendenciaConferencia(
        insumo: insumo,
        quantidadeRetiradaPendente: quantidadeRetiradaPendente,
        ultimaRetiradaEm: ultimaRetiradaEm,
      ));
    }

    pendencias.sort((a, b) => a.ultimaRetiradaEm.compareTo(b.ultimaRetiradaEm));
    return pendencias;
  }

  /// Registra a conferência: se bateu, só marca resolvido; se divergiu,
  /// já corrige o estoque (via `atualizarContagem`) e grava a ocorrência
  /// com a observação de quem conferiu.
  Future<void> registrarConferencia({
    required InsumoObraRecord insumo,
    required double quantidadeConferida,
    String? observacao,
  }) async {
    final agora = DateTime.now();
    final divergencia = quantidadeConferida - insumo.quantidadeAtual;

    if (divergencia != 0) {
      await atualizarContagem(insumo, quantidadeConferida);
    }

    final registro = InsumoConferenciaRecord(
      id: 'insumoconf_${agora.microsecondsSinceEpoch}',
      projectId: insumo.projectId,
      insumoId: insumo.id,
      material: insumo.material,
      unidade: insumo.unidade,
      quantidadeEsperada: insumo.quantidadeAtual,
      quantidadeConferida: quantidadeConferida,
      divergencia: divergencia,
      observacao: (observacao ?? '').trim().isEmpty ? null : observacao!.trim(),
      pendingSync: true,
      createdAt: agora,
    );
    await _conferencias.put(registro.id, registro);
    await _mirror(
      'projects/${insumo.projectId}/insumos_obra_conferencias/${registro.id}',
      registro.toMap(),
    );
  }

  /// Histórico de conferências — `somenteComDivergencia` filtra só as
  /// ocorrências (furos/sobras), que é o que normalmente importa revisar.
  List<InsumoConferenciaRecord> historicoConferencias(
    String projectId, {
    bool somenteComDivergencia = false,
  }) {
    final list = _conferencias.values
        .where((c) => c.projectId == projectId && !c.deleted)
        .where((c) => !somenteComDivergencia || c.temDivergencia)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }
}

/// Um insumo pendente de reconferência — some da lista assim que alguém
/// registra a conferência dele.
class PendenciaConferencia {
  const PendenciaConferencia({
    required this.insumo,
    required this.quantidadeRetiradaPendente,
    required this.ultimaRetiradaEm,
  });

  final InsumoObraRecord insumo;
  final double quantidadeRetiradaPendente;
  final DateTime ultimaRetiradaEm;
}
