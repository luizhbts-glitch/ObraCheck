import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/medicao_campo_record.dart';
import '../utils/medicao_campo_rules.dart';
import 'medicao_foto_service.dart';
import 'photo_service.dart';
import 'project_context_service.dart';
import 'user_profile_service.dart';

class MedicaoSyncResult {
  const MedicaoSyncResult({
    this.enviadas = 0,
    this.baixadas = 0,
    this.fotosEnviadas = 0,
    this.falhas = 0,
    this.erro,
  });

  final int enviadas;
  final int baixadas;
  final int fotosEnviadas;
  final int falhas;
  final String? erro;

  bool get ok => erro == null && falhas == 0;
}

/// Medição de campo — Hive primeiro (tudo funciona offline); a sincronização
/// envia o que está pendente (fotos pro Storage, dados pro Firestore) e baixa
/// o que outros aparelhos criaram. Registro com alteração local pendente
/// nunca é sobrescrito pelo que vem da nuvem.
class MedicaoCampoService {
  MedicaoCampoService._();

  static final MedicaoCampoService instance = MedicaoCampoService._();

  static const String boxName = 'medicoes_campo';
  static const Duration _firestoreTimeout = Duration(seconds: 15);
  static const Duration _uploadTimeout = Duration(seconds: 90);

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseStorage get _storage => FirebaseStorage.instance;

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

  CollectionReference<Map<String, dynamic>> _colecao(String projectId) =>
      _firestore.collection('projects/$projectId/medicoes_campo');

  List<MedicaoCampoRecord> listar(String projectId) {
    final list =
        box.values.where((m) => m.projectId == projectId && !m.deleted).toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  /// Medições (inclusive excluídas) com alteração ainda não enviada.
  int pendentes(String projectId) =>
      box.values.where((m) => m.projectId == projectId && m.pendingSync).length;

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
    List<String> elementos = const [],
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
      elementos: elementos,
    );
    await box.put(record.id, record);
    unawaited(sincronizar(projectId, baixar: false));
    return record;
  }

  /// Regrava a medição inteira (usado ao editar dados, aptos, fotos ou
  /// status). O envio pra nuvem acontece em segundo plano.
  Future<MedicaoCampoRecord> salvar(MedicaoCampoRecord record) async {
    final atualizado = record.copyWith(
      pendingSync: true,
      updatedAt: DateTime.now(),
    );
    await box.put(atualizado.id, atualizado);
    unawaited(sincronizar(atualizado.projectId, baixar: false));
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
    unawaited(sincronizar(tombstone.projectId, baixar: false));
  }

  // ── Sincronização ───────────────────────────────────────────────────

  bool _sincronizando = false;
  bool _novaRodada = false;

  /// Envia o que está pendente e (se [baixar]) traz o que outros aparelhos
  /// criaram. Nunca lança: falha de rede vira `erro` no resultado e o que não
  /// subiu continua pendente pra próxima tentativa.
  Future<MedicaoSyncResult> sincronizar(
    String projectId, {
    bool baixar = true,
  }) async {
    if (projectId.trim().isEmpty) return const MedicaoSyncResult();
    if (_sincronizando) {
      _novaRodada = true;
      return const MedicaoSyncResult();
    }
    _sincronizando = true;
    var enviadas = 0;
    var baixadas = 0;
    var fotos = 0;
    var falhas = 0;
    String? erro;
    try {
      final locais = box.values
          .where((m) => m.projectId == projectId && m.pendingSync)
          .toList();
      for (final record in locais) {
        try {
          final r = await _enviar(record);
          fotos += r.fotos;
          enviadas++;
        } catch (e) {
          falhas++;
          erro ??= e.toString();
          debugPrint('[MEDICAO_CAMPO] Falha ao enviar ${record.id}: $e');
        }
      }
      if (baixar) {
        try {
          baixadas = await _baixar(projectId);
        } catch (e) {
          erro ??= e.toString();
          debugPrint('[MEDICAO_CAMPO] Falha ao baixar medições: $e');
        }
      }
    } finally {
      _sincronizando = false;
    }
    if (_novaRodada) {
      _novaRodada = false;
      unawaited(sincronizar(projectId, baixar: false));
    }
    return MedicaoSyncResult(
      enviadas: enviadas,
      baixadas: baixadas,
      fotosEnviadas: fotos,
      falhas: falhas,
      erro: erro,
    );
  }

  String _segmentoObra(MedicaoCampoRecord record) {
    final ctx = ProjectContextService.instance;
    final code = ctx.currentProjectIdSync == record.projectId
        ? ctx.currentProjectCodeSync
        : '';
    final base = code.trim().isNotEmpty ? code : record.projectId;
    final seg = PhotoService.instance.sanitizeSegment(base);
    return seg.isEmpty ? 'SEM-OBRA' : seg;
  }

  Future<({int fotos})> _enviar(MedicaoCampoRecord inicial) async {
    var record = inicial;
    var fotosEnviadas = 0;

    if (!record.deleted) {
      final aptos = <MedicaoCampoApto>[];
      for (final apto in record.aptos) {
        final novas = <MedicaoCampoFoto>[];
        for (final foto in apto.fotos) {
          if (foto.photoUrl.isNotEmpty) {
            novas.add(foto);
            continue;
          }
          final bytes = await MedicaoFotoService.instance.lerBytes(foto);
          if (bytes == null) {
            novas.add(foto);
            continue;
          }
          final isJpeg = bytes.length > 2 && bytes[0] == 0xFF && bytes[1] == 0xD8;
          final path =
              'obras/${_segmentoObra(record)}/medicao_campo/${record.id}/${foto.id}.${isJpeg ? 'jpg' : 'png'}';
          final ref = _storage.ref().child(path);
          await ref
              .putData(
                bytes,
                SettableMetadata(contentType: isJpeg ? 'image/jpeg' : 'image/png'),
              )
              .timeout(_uploadTimeout);
          final url = await ref.getDownloadURL().timeout(_firestoreTimeout);
          novas.add(
            foto.copyWith(photoUrl: url, storagePath: path, pendingSync: false),
          );
          fotosEnviadas++;
        }
        aptos.add(apto.copyWith(fotos: novas));
      }
      record = record.copyWith(aptos: aptos);
    }

    final remoto = {...record.toMap(), 'pendingSync': false};
    await _colecao(record.projectId)
        .doc(record.id)
        .set(remoto, SetOptions(merge: true))
        .timeout(_firestoreTimeout);

    // Só desmarca a pendência se ninguém mexeu na medição enquanto subia.
    final atual = box.get(record.id);
    final mudouNoMeio =
        atual != null && atual.updatedAt.isAfter(inicial.updatedAt);
    if (mudouNoMeio) {
      // Mantém a edição nova pendente, mas aproveita as URLs já enviadas.
      await box.put(
        atual.id,
        atual.copyWith(aptos: mesclarUrlsDeFotos(atual.aptos, record.aptos)),
      );
    } else {
      await box.put(record.id, record.copyWith(pendingSync: false));
    }
    return (fotos: fotosEnviadas);
  }

  Future<int> _baixar(String projectId) async {
    final snap = await _colecao(projectId).get().timeout(_firestoreTimeout);
    var baixadas = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      data['id'] = (data['id'] ?? doc.id).toString();
      final remoto = MedicaoCampoRecord.fromMap(data);
      if (remoto.projectId != projectId) continue;
      final local = box.get(remoto.id);

      if (local == null) {
        if (remoto.deleted) continue;
        await box.put(remoto.id, remoto.copyWith(pendingSync: false));
        baixadas++;
        continue;
      }
      if (local.pendingSync) continue;
      if (!remoto.updatedAt.isAfter(local.updatedAt)) continue;

      await box.put(
        remoto.id,
        remoto.copyWith(
          pendingSync: false,
          aptos: preservarArquivosLocais(local.aptos, remoto.aptos),
        ),
      );
      baixadas++;
    }
    return baixadas;
  }
}
