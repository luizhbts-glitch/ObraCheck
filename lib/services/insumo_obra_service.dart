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
  }) async {
    final now = DateTime.now();
    final record = InsumoObraRecord(
      id: 'insumo_${now.microsecondsSinceEpoch}',
      projectId: projectId,
      material: material.trim(),
      endereco: endereco.trim(),
      estoqueMinimo: estoqueMinimo,
      quantidadeAtual: quantidadeInicial,
      pendingSync: true,
      createdAt: now,
      updatedAt: now,
    );
    await _insumos.put(record.id, record);
    await _mirror('projects/$projectId/insumos_obra/${record.id}', record.toMap());
    return record;
  }

  Future<void> editar(InsumoObraRecord atual, {String? material, String? endereco, double? estoqueMinimo}) async {
    final atualizado = atual.copyWith(
      material: material?.trim(),
      endereco: endereco?.trim(),
      estoqueMinimo: estoqueMinimo,
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
}
