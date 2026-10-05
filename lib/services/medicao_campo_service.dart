import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/medicao_campo_record.dart';
import 'user_profile_service.dart';

/// Medição de campo — mesmo padrão Hive-first / espelho Firestore em melhor
/// esforço dos outros serviços do ERP (Insumos, Compras): grava local sempre,
/// espelha só metadados no Firestore (as imagens vão pro Storage, que depende
/// do faturamento do projeto estar ativo). Sem checagem de permissão aqui.
class MedicaoCampoService {
  MedicaoCampoService._();

  static final MedicaoCampoService instance = MedicaoCampoService._();

  static const String boxName = 'medicoes_campo';
  static const Duration _firestoreTimeout = Duration(seconds: 10);

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  Box<MedicaoCampoRecord> get box => Hive.box<MedicaoCampoRecord>(boxName);

  static const String _userNameKey = 'medicao_campo_user_name';

  String _pastasKey(String projectId) => 'medicao_campo_pastas_$projectId';

  /// Pastas criadas antes de existir medição dentro: `'2026'` (ano) e
  /// `'2026|9'` (mês). Ficam em `prefs`; o resto da hierarquia sai das
  /// próprias medições.
  Set<String> pastasVazias(String projectId) {
    if (!Hive.isBoxOpen('prefs')) return <String>{};
    final raw = Hive.box('prefs').get(_pastasKey(projectId));
    return ((raw as List?) ?? const []).map((e) => e.toString()).toSet();
  }

  Future<void> criarPasta(String projectId, String pasta) async {
    final atuais = pastasVazias(projectId)..add(pasta);
    await Hive.box('prefs').put(_pastasKey(projectId), atuais.toList());
  }

  /// Nome de quem está medindo — precisa funcionar offline (vai na marca
  /// d'água da foto). Tenta o perfil (Firestore) por pouco tempo e cai pro
  /// último nome conhecido, depois pro `FirebaseAuth`.
  Future<String> resolverNomeUsuario() async {
    final prefs = Hive.isBoxOpen('prefs') ? Hive.box('prefs') : null;
    try {
      final profile = await UserProfileService.instance
          .getCurrentUserProfile()
          .timeout(const Duration(seconds: 4));
      final nome = (profile?.nome ?? '').trim();
      if (nome.isNotEmpty) {
        await prefs?.put(_userNameKey, nome);
        return nome;
      }
    } catch (_) {}
    final cached = (prefs?.get(_userNameKey) ?? '').toString().trim();
    if (cached.isNotEmpty) return cached;
    try {
      final user = FirebaseAuth.instance.currentUser;
      final display = (user?.displayName ?? '').trim();
      if (display.isNotEmpty) return display;
      final email = (user?.email ?? '').trim();
      if (email.isNotEmpty) return email.split('@').first;
    } catch (_) {}
    return '';
  }

  Future<void> _mirror(String path, Map<String, dynamic> data) async {
    try {
      await _firestore
          .doc(path)
          .set(data, SetOptions(merge: true))
          .timeout(_firestoreTimeout);
    } catch (e) {
      debugPrint('[MEDICAO_CAMPO] Falha ao espelhar $path no Firestore: $e');
    }
  }

  String _path(MedicaoCampoRecord r) =>
      'projects/${r.projectId}/medicoes_campo/${r.id}';

  List<MedicaoCampoRecord> listar(String projectId) {
    final list =
        box.values.where((m) => m.projectId == projectId && !m.deleted).toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  MedicaoCampoRecord? buscar(String id) => box.get(id);

  Future<MedicaoCampoRecord> criar({
    required String projectId,
    required String obra,
    required String servicoCodigo,
    required String servicoNome,
    required String empreiteiroId,
    required String empreiteiroNome,
    required String periodo,
    required String responsavelNome,
    required int ano,
    required int mes,
    required List<MedicaoCampoApto> aptos,
  }) async {
    final now = DateTime.now();
    final record = MedicaoCampoRecord(
      id: 'medcampo_${now.microsecondsSinceEpoch}',
      projectId: projectId,
      obra: obra,
      servicoCodigo: servicoCodigo,
      servicoNome: servicoNome,
      empreiteiroId: empreiteiroId,
      empreiteiroNome: empreiteiroNome,
      periodo: periodo.trim(),
      responsavelNome: responsavelNome.trim(),
      aptos: aptos,
      pendingSync: true,
      createdAt: now,
      updatedAt: now,
      ano: ano,
      mes: mes,
    );
    await box.put(record.id, record);
    unawaited(_mirror(_path(record), record.toMap()));
    return record;
  }

  /// Regrava a medição inteira (usado ao editar dados, aptos, fotos ou
  /// status). O espelho no Firestore não bloqueia o fluxo local.
  Future<MedicaoCampoRecord> salvar(MedicaoCampoRecord record) async {
    final atualizado = record.copyWith(
      pendingSync: true,
      updatedAt: DateTime.now(),
    );
    await box.put(atualizado.id, atualizado);
    unawaited(_mirror(_path(atualizado), atualizado.toMap()));
    return atualizado;
  }

  /// Atualiza um apto dentro da medição (status, observação, fotos).
  Future<MedicaoCampoRecord> atualizarApto(
    MedicaoCampoRecord record,
    MedicaoCampoApto apto,
  ) {
    final aptos = record.aptos
        .map((a) => a.chave == apto.chave ? apto : a)
        .toList(growable: false);
    return salvar(record.copyWith(aptos: aptos));
  }

  Future<void> excluir(MedicaoCampoRecord record) async {
    final tombstone = record.copyWith(
      deleted: true,
      pendingSync: true,
      updatedAt: DateTime.now(),
    );
    await box.put(tombstone.id, tombstone);
    unawaited(_mirror(_path(tombstone), tombstone.toMap()));
  }
}
