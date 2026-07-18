import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/construtora_record.dart';
import '../models/project_record.dart';
import '../models/user_org_membership.dart';
import 'project_context_service.dart';

class OrgActionResult {
  const OrgActionResult({required this.success, required this.message});

  final bool success;
  final String message;
}

/// Operações de administração de construtoras — restritas na prática ao
/// admin global (a UI é bloqueada por AppPermission.manageConstrutoras e
/// as firestore.rules vão reforçar no servidor na etapa 4).
class ConstrutoraAdminService {
  ConstrutoraAdminService._();

  static final ConstrutoraAdminService instance = ConstrutoraAdminService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Box<ConstrutoraRecord> get _construtoras =>
      Hive.box<ConstrutoraRecord>('construtoras');
  Box<UserOrgMembership> get _orgMemberships =>
      Hive.box<UserOrgMembership>('user_org_memberships');
  Box<ProjectRecord> get _projects => Hive.box<ProjectRecord>('projects');

  List<ConstrutoraRecord> allConstrutoras() {
    final out = _construtoras.values.where((c) => c.isActive).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return out;
  }

  List<ProjectRecord> projectsOfOrg(String orgId) {
    final normalized = orgId.trim();
    if (normalized.isEmpty) return const <ProjectRecord>[];
    return _projects.values
        .where((p) => p.orgId.trim() == normalized)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  List<UserOrgMembership> diretoresOfOrg(String orgId) {
    final normalized = orgId.trim();
    if (normalized.isEmpty) return const <UserOrgMembership>[];
    return _orgMemberships.values
        .where((m) => m.orgId.trim() == normalized)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<ConstrutoraRecord> createConstrutora(String name) async {
    final now = DateTime.now();
    final normalizedName = name.trim();
    final slug = normalizedName
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');
    final id = slug.isEmpty ? 'org_${now.microsecondsSinceEpoch}' : slug;

    final record = ConstrutoraRecord(
      id: id,
      name: normalizedName.isEmpty ? 'Nova construtora' : normalizedName,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );

    await _construtoras.put(record.id, record);

    try {
      await _firestore
          .collection('construtoras')
          .doc(record.id)
          .set(record.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('[ORG_ADMIN] Falha ao persistir construtora no Firestore: $e');
    }

    return record;
  }

  /// Vincula (orgId preenchido) ou desvincula (orgId vazio) uma obra.
  Future<void> setProjectOrg({
    required String projectId,
    required String orgId,
  }) async {
    final project = _projects.get(projectId.trim());
    if (project == null) return;

    final updated = project.copyWith(
      orgId: orgId.trim(),
      updatedAt: DateTime.now(),
    );
    await _projects.put(updated.id, updated);

    try {
      await _firestore.collection('projects').doc(updated.id).set(
        {'orgId': updated.orgId, 'updatedAt': Timestamp.fromDate(updated.updatedAt)},
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('[ORG_ADMIN] Falha ao persistir orgId no Firestore: $e');
    }

    // Papel efetivo e lista de obras visíveis podem ter mudado.
    await ProjectContextService.instance.hydrateCurrentProject();
  }

  /// Vincula um diretor pela conta de e-mail já existente no app.
  /// (v1: sem convite pendente de org — quem ainda não tem conta precisa
  /// criá-la antes; como só o admin global usa esta tela, dá pra coordenar.)
  Future<OrgActionResult> addDiretorByEmail({
    required String orgId,
    required String email,
  }) async {
    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty || !normalizedEmail.contains('@')) {
      return const OrgActionResult(
        success: false,
        message: 'Informe um email válido.',
      );
    }

    try {
      final userSnap = await _firestore
          .collection('users')
          .where('email', isEqualTo: normalizedEmail)
          .limit(1)
          .get();

      if (userSnap.docs.isEmpty) {
        return const OrgActionResult(
          success: false,
          message:
              'Nenhuma conta encontrada com este email. A pessoa precisa criar a conta no app primeiro.',
        );
      }

      final uid = userSnap.docs.first.id;
      final now = DateTime.now();
      final membershipId = '${uid}_${orgId.trim()}';
      final existing = _orgMemberships.get(membershipId);

      final membership = (existing ??
              UserOrgMembership(
                id: membershipId,
                userId: uid,
                orgId: orgId.trim(),
                role: UserOrgMembership.roleDiretor,
                isActive: true,
                createdAt: now,
                updatedAt: now,
              ))
          .copyWith(isActive: true, updatedAt: now);

      await _orgMemberships.put(membership.id, membership);
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('org_memberships')
          .doc(membership.id)
          .set(membership.toMap(), SetOptions(merge: true));

      return OrgActionResult(
        success: true,
        message: existing == null
            ? 'Diretor vinculado à construtora.'
            : 'Vínculo de diretor reativado.',
      );
    } catch (e) {
      return OrgActionResult(
        success: false,
        message: 'Falha ao vincular diretor (verifique a conexão): $e',
      );
    }
  }

  Future<void> setDiretorActive({
    required UserOrgMembership membership,
    required bool isActive,
  }) async {
    final updated = membership.copyWith(
      isActive: isActive,
      updatedAt: DateTime.now(),
    );
    await _orgMemberships.put(updated.id, updated);

    try {
      await _firestore
          .collection('users')
          .doc(updated.userId)
          .collection('org_memberships')
          .doc(updated.id)
          .set(updated.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('[ORG_ADMIN] Falha ao atualizar diretor no Firestore: $e');
    }
  }

  /// Puxa construtoras do Firestore pro cache local (admin global).
  Future<void> refreshFromRemote() async {
    try {
      final snap = await _firestore.collection('construtoras').get();
      for (final doc in snap.docs) {
        final rec = ConstrutoraRecord.fromMap({
          ...doc.data(),
          'id': doc.data()['id']?.toString().isNotEmpty == true
              ? doc.data()['id']
              : doc.id,
        });
        await _construtoras.put(rec.id, rec);
      }
    } catch (e) {
      debugPrint('[ORG_ADMIN] refreshFromRemote falhou (mantendo cache): $e');
    }
  }
}
