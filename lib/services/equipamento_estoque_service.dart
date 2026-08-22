import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/equipamento_estoque_record.dart';

/// Controle de estoque de equipamentos (próprio/alugado/de terceiro),
/// separado do controle de saída/devolução já existente. Cada escrita
/// salva local (Hive, offline-first) e espelha pro Firestore em melhor
/// esforço — mesmo padrão do resto do módulo de Compras
/// (`ComprasService`): sem checagem de permissão aqui, quem chama (a
/// tela) é responsável por isso.
class EquipamentoEstoqueService {
  EquipamentoEstoqueService._();

  static final EquipamentoEstoqueService instance = EquipamentoEstoqueService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Box<EquipamentoEstoqueRecord> get _box =>
      Hive.box<EquipamentoEstoqueRecord>('equipamentos_estoque');

  Future<void> _mirror(String path, Map<String, dynamic> data) async {
    try {
      await _firestore.doc(path).set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[EQUIPAMENTO_ESTOQUE] Falha ao espelhar $path no Firestore: $e');
    }
  }

  List<EquipamentoEstoqueRecord> porTipo(String projectId, String tipo) {
    final list = _box.values
        .where((e) => e.projectId == projectId && e.tipo == tipo && !e.deleted)
        .toList()
      ..sort((a, b) => a.material.toLowerCase().compareTo(b.material.toLowerCase()));
    return list;
  }

  Future<EquipamentoEstoqueRecord> criar({
    required String projectId,
    required String tipo,
    required String material,
    String? marca,
    String? descricao,
    String? terceiroNome,
    DateTime? periodoInicio,
    DateTime? periodoFim,
    String? locadora,
    String? centroCusto,
    double? valor,
  }) async {
    final now = DateTime.now();
    final record = EquipamentoEstoqueRecord(
      id: 'eqest_${now.microsecondsSinceEpoch}',
      projectId: projectId,
      tipo: tipo,
      material: material.trim(),
      marca: (marca ?? '').trim().isEmpty ? null : marca!.trim(),
      descricao: (descricao ?? '').trim().isEmpty ? null : descricao!.trim(),
      terceiroNome: (terceiroNome ?? '').trim().isEmpty ? null : terceiroNome!.trim(),
      periodoInicio: periodoInicio,
      periodoFim: periodoFim,
      locadora: (locadora ?? '').trim().isEmpty ? null : locadora!.trim(),
      centroCusto: (centroCusto ?? '').trim().isEmpty ? null : centroCusto!.trim(),
      valor: valor,
      pendingSync: true,
      createdAt: now,
      updatedAt: now,
    );
    await _box.put(record.id, record);
    await _mirror('projects/$projectId/equipamentos_estoque/${record.id}', record.toMap());
    return record;
  }

  Future<void> atualizar(EquipamentoEstoqueRecord atualizado) async {
    final withMeta = atualizado.copyWith(pendingSync: true, updatedAt: DateTime.now());
    await _box.put(withMeta.id, withMeta);
    await _mirror(
      'projects/${withMeta.projectId}/equipamentos_estoque/${withMeta.id}',
      withMeta.toMap(),
    );
  }

  Future<void> excluir(EquipamentoEstoqueRecord record) async {
    final tombstone = record.copyWith(deleted: true, pendingSync: true, updatedAt: DateTime.now());
    await _box.put(tombstone.id, tombstone);
    await _mirror(
      'projects/${tombstone.projectId}/equipamentos_estoque/${tombstone.id}',
      tombstone.toMap(),
    );
  }

  /// Agrupa os equipamentos "de terceiro" por [EquipamentoEstoqueRecord.terceiroNome]
  /// — um cartão por subcontratado, cada um com sua lista de equipamentos.
  Map<String, List<EquipamentoEstoqueRecord>> agruparPorTerceiro(String projectId) {
    final map = <String, List<EquipamentoEstoqueRecord>>{};
    for (final e in porTipo(projectId, TipoEquipamentoEstoque.terceiro)) {
      final nome = (e.terceiroNome ?? '').trim();
      if (nome.isEmpty) continue;
      map.putIfAbsent(nome, () => []).add(e);
    }
    return map;
  }
}
