// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

import '../models/project_record.dart';
import '../models/project_invite_record.dart';
import '../models/project_access_code_record.dart';
import '../models/user_project_membership.dart';
import 'auth_service.dart';
import 'project_context_service.dart';
import 'user_profile_service.dart';

class InviteResult {
  final bool membershipCreated;
  final bool pendingInviteCreated;
  final String message;

  const InviteResult({
    required this.membershipCreated,
    required this.pendingInviteCreated,
    required this.message,
  });
}

class AccessCodeCreateResult {
  final bool created;
  final String message;
  final ProjectAccessCodeRecord? code;

  const AccessCodeCreateResult({
    required this.created,
    required this.message,
    required this.code,
  });
}

class AccessCodeConsumeResult {
  final bool success;
  final String message;

  const AccessCodeConsumeResult({
    required this.success,
    required this.message,
  });
}

class _AccessCodeValidationResult {
  const _AccessCodeValidationResult._({
    required this.valid,
    this.message,
  });

  const _AccessCodeValidationResult.valid() : this._(valid: true);

  const _AccessCodeValidationResult.invalid(String message)
      : this._(valid: false, message: message);

  final bool valid;
  final String? message;
}

class ProjectMembersService {
  ProjectMembersService._();

  static final ProjectMembersService instance = ProjectMembersService._();
  static const String _masterBootstrapCode = 'MASTER-CHECK-001';

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  Box<UserProjectMembership> get _memberships => Hive.box<UserProjectMembership>('user_project_memberships');
  Box<ProjectRecord> get _projects => Hive.box<ProjectRecord>('projects');
  Box<ProjectInviteRecord> get _invites => Hive.box<ProjectInviteRecord>('project_invites');
  Box<ProjectAccessCodeRecord> get _accessCodes =>
      Hive.box<ProjectAccessCodeRecord>('project_access_codes');

  List<UserProjectMembership> membershipsForCurrentProject() {
    final projectId = ProjectContextService.instance.currentProjectIdSync;
    final items = _memberships.values
        .where((m) => m.isActive && m.projectId == projectId)
        .toList()
      ..sort((a, b) => a.userId.compareTo(b.userId));
    return items;
  }

  List<ProjectInviteRecord> pendingInvitesForCurrentProject() {
    final projectId = ProjectContextService.instance.currentProjectIdSync;
    final items = _invites.values
        .where((i) => i.projectId == projectId && i.status == ProjectInviteRecord.statusPending)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return items;
  }

  List<ProjectAccessCodeRecord> activeAccessCodesForCurrentProject() {
    final projectId = ProjectContextService.instance.currentProjectIdSync;
    final items = _accessCodes.values
        .where((code) =>
            code.projectId == projectId &&
            code.active &&
            !code.isExpired &&
            code.remainingUses > 0)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  String _generateReadableCode() {
    final ms = DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase();
    final suffix = ms.length >= 8 ? ms.substring(ms.length - 8) : ms.padLeft(8, '0');
    return 'OC-$suffix';
  }

  Future<AccessCodeCreateResult> createTemporaryAccessCode({
    required String role,
    DateTime? expiresAt,
    required int maxUses,
    bool isMaster = false,
  }) async {
    final project = ProjectContextService.instance.currentProject;
    final projectId = ProjectContextService.instance.currentProjectIdSync;
    final currentUser = AuthService.instance.currentUser;
    if (project == null || projectId.trim().isEmpty || currentUser == null) {
      return const AccessCodeCreateResult(
        created: false,
        message: 'Contexto de obra/usuário indisponível.',
        code: null,
      );
    }

    final normalizedRole = isMaster ? UserProjectMembership.roleAdmin : role;

    if (expiresAt != null && expiresAt.isBefore(DateTime.now())) {
      return const AccessCodeCreateResult(
        created: false,
        message: 'A validade precisa estar no futuro.',
        code: null,
      );
    }

    if (maxUses <= 0) {
      return const AccessCodeCreateResult(
        created: false,
        message: 'A quantidade de usos deve ser maior que zero.',
        code: null,
      );
    }

    final profile = await UserProfileService.instance.getCurrentUserProfile();
    final now = DateTime.now();
    final codeValue = _generateReadableCode();
    final id = '${projectId}_${codeValue.replaceAll('-', '_')}';

    final record = ProjectAccessCodeRecord(
      id: id,
      projectId: projectId,
      code: codeValue,
      role: normalizedRole,
      expiresAt: expiresAt,
      maxUses: maxUses,
      usedCount: 0,
      isActive: true,
      isMaster: isMaster,
      createdByUid: currentUser.uid,
      createdByName: profile?.nome.trim().isNotEmpty == true
          ? profile!.nome.trim()
          : null,
      createdAt: now,
      updatedAt: now,
      pendingSync: true,
      syncError: null,
    );

    await _accessCodes.put(record.id, record);

    try {
      await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('access_codes')
          .doc(record.id)
          .set(record.toMap(), SetOptions(merge: true));

      await _accessCodes.put(
        record.id,
        record.copyWith(
          pendingSync: false,
          syncError: null,
          updatedAt: DateTime.now(),
        ),
      );

      return AccessCodeCreateResult(
        created: true,
        message: 'Código gerado com sucesso.',
        code: record,
      );
    } catch (e) {
      await _accessCodes.put(
        record.id,
        record.copyWith(
          pendingSync: true,
          syncError: e.toString(),
          updatedAt: DateTime.now(),
        ),
      );
      return AccessCodeCreateResult(
        created: true,
        message: 'Código salvo localmente e pendente de sincronização.',
        code: record,
      );
    }
  }

  Future<AccessCodeConsumeResult> consumeAccessCode({
    required String code,
  }) async {
    const diag = '[ACCESS_CODE]';
    final normalized = code.trim().toUpperCase();
    print('$diag inputCode=$code normalized=$normalized');
    if (normalized.isEmpty) {
      return const AccessCodeConsumeResult(
        success: false,
        message: 'Informe um código de acesso.',
      );
    }

    final user = AuthService.instance.currentUser;
    if (user == null) {
      return const AccessCodeConsumeResult(
        success: false,
        message: 'Usuário não autenticado.',
      );
    }
    print('$diag userId=${user.uid}');

    if (normalized == _masterBootstrapCode) {
      return _consumeMasterBootstrapCode(userId: user.uid);
    }

    ProjectAccessCodeRecord? found = _accessCodes.values
        .where((entry) => entry.code.trim().toUpperCase() == normalized)
        .cast<ProjectAccessCodeRecord?>()
        .firstWhere((e) => e != null, orElse: () => null);
    print('$diag localLookup found=${found != null}');
    String? remoteLookupErrorMessage;

    DocumentReference<Map<String, dynamic>>? remoteCodeRef;

    if (found == null) {
      try {
        final snap = await _firestore
            .collectionGroup('access_codes')
            .where('code', isEqualTo: normalized)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) {
          remoteCodeRef = snap.docs.first.reference;
          final data = Map<String, dynamic>.from(snap.docs.first.data());
          found = ProjectAccessCodeRecord.fromMap({
            ...data,
            'id': data['id']?.toString().isNotEmpty == true
                ? data['id']
                : snap.docs.first.id,
          });
          await _accessCodes.put(found.id, found);
          print(
            '$diag remoteLookup found=true '
            'projectId=${found.projectId} codeId=${found.id} path=${remoteCodeRef.path}',
          );
        } else {
          print('$diag remoteLookup found=false');
        }
      } on FirebaseException catch (e) {
        print('$diag remoteLookup errorCode=${e.code} errorMessage=${e.message}');
        final normalizedCode = e.code.trim().toLowerCase();
        if (normalizedCode == 'failed-precondition') {
          remoteLookupErrorMessage =
              'Busca remota indisponível no momento. Verifique a configuração do Firestore.';
        } else {
          remoteLookupErrorMessage =
              'Falha ao validar código no servidor. Tente novamente em instantes.';
        }
      } catch (e) {
        print('$diag remoteLookup error=$e');
        remoteLookupErrorMessage =
            'Falha ao validar código no servidor. Tente novamente em instantes.';
      }
    }

    if (found == null) {
      print('$diag codeNotFound normalized=$normalized');
      if (remoteLookupErrorMessage != null) {
        return AccessCodeConsumeResult(
          success: false,
          message: remoteLookupErrorMessage,
        );
      }
      return const AccessCodeConsumeResult(
        success: false,
        message: 'Código inválido.',
      );
    }
    var codeRecord = found;

    remoteCodeRef ??=
        await _resolveRemoteCodeRefById(codeRecord.projectId, codeRecord.id);

    print(
      '$diag codeResolved '
      'projectId=${codeRecord.projectId} codeId=${codeRecord.id} '
      'role=${codeRecord.role} expiresAt=${codeRecord.expiresAt} '
      'maxUses=${codeRecord.maxUses} usedCount=${codeRecord.usedCount} active=${codeRecord.active}',
    );

    final validation = _validateCodeForConsumption(codeRecord);
    if (!validation.valid) {
      print('$diag validationFail message=${validation.message}');
      return AccessCodeConsumeResult(
        success: false,
        message: validation.message ?? 'Código inválido.',
      );
    }

    final now = DateTime.now();
    final roleToAssign = codeRecord.isMaster
        ? UserProjectMembership.roleAdmin
        : codeRecord.role;

    if (codeRecord.isMaster && codeRecord.maxUses > 1) {
      return const AccessCodeConsumeResult(
        success: false,
        message: 'Código mestre deve ter uso limitado (recomendado: 1).',
      );
    }

    final membershipId = '${user.uid}_${codeRecord.projectId}';
    final existing = _memberships.get(membershipId) ??
        _memberships.values
            .where((m) => m.userId == user.uid && m.projectId == codeRecord.projectId)
            .cast<UserProjectMembership?>()
            .firstWhere((m) => m != null, orElse: () => null);
    final membershipCreated = existing == null;

    final membership = (existing ??
            UserProjectMembership(
              id: membershipId,
              userId: user.uid,
              projectId: codeRecord.projectId,
              role: roleToAssign,
              isActive: true,
              createdAt: now,
              updatedAt: now,
            ))
        .copyWith(
      role: roleToAssign,
      isActive: true,
      updatedAt: now,
    );

    ProjectAccessCodeRecord consumed = codeRecord.copyWith(
      usedCount: codeRecord.usedCount + 1,
      isActive: (codeRecord.usedCount + 1) < codeRecord.maxUses,
      updatedAt: now,
      pendingSync: true,
      syncError: null,
    );

    print(
      '$diag membershipPrepare '
      'membershipCreated=$membershipCreated membershipId=${membership.id} '
      'userId=${membership.userId} projectId=${membership.projectId} role=${membership.role}',
    );

    if (remoteCodeRef != null) {
      try {
        final remoteConsumed = await _consumeCodeRemoteAtomically(
          codeRef: remoteCodeRef,
        );
        consumed = remoteConsumed.copyWith(
          pendingSync: false,
          syncError: null,
          updatedAt: DateTime.now(),
        );
      } catch (e) {
        final fallbackValidation = _validateCodeForConsumption(codeRecord);
        if (!fallbackValidation.valid) {
          print('$diag remoteConsumeFail validationAfterError=${fallbackValidation.message}');
          return AccessCodeConsumeResult(
            success: false,
            message: fallbackValidation.message ?? 'Código inválido.',
          );
        }
        print('$diag remoteConsumeFail fallbackToLocal error=$e');
      }
    }

    await _memberships.put(membership.id, membership);
    await _accessCodes.put(consumed.id, consumed);
    print(
      '$diag localPersist '
      'membershipSaved=true codeUsageUpdated=true usedCount=${consumed.usedCount} active=${consumed.active}',
    );

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('project_memberships')
          .doc(membership.id)
          .set(membership.toMap(), SetOptions(merge: true));

      await _firestore
          .collection('projects')
          .doc(consumed.projectId)
          .collection('access_codes')
          .doc(consumed.id)
          .set(consumed.toMap(), SetOptions(merge: true));

      print(
        '$diag remotePersist success '
        'membershipPath=users/${user.uid}/project_memberships/${membership.id} '
        'codePath=projects/${consumed.projectId}/access_codes/${consumed.id}',
      );

      await _accessCodes.put(
        consumed.id,
        consumed.copyWith(
          pendingSync: false,
          syncError: null,
          updatedAt: DateTime.now(),
        ),
      );
    } catch (e) {
      print('$diag remotePersist fail error=$e');
      await _accessCodes.put(
        consumed.id,
        consumed.copyWith(
          pendingSync: true,
          syncError: e.toString(),
          updatedAt: DateTime.now(),
        ),
      );
    }

    final projectReady = await _ensureProjectAvailableLocally(codeRecord.projectId);
    print('$diag projectResolved projectId=${codeRecord.projectId} ready=$projectReady');
    try {
      await ProjectContextService.instance.refreshMembershipsForCurrentUser();
      await ProjectContextService.instance.hydrateCurrentProject();
      await ProjectContextService.instance.switchProject(codeRecord.projectId);
      print('$diag projectActivated projectId=${codeRecord.projectId}');
    } catch (e) {
      print('$diag projectActivateFail projectId=${codeRecord.projectId} error=$e');
    }

    return const AccessCodeConsumeResult(
      success: true,
      message: 'Acesso liberado com sucesso.',
    );
  }

  Future<bool> _ensureProjectAvailableLocally(String projectId) async {
    final pid = projectId.trim();
    if (pid.isEmpty) return false;

    final existing = _projects.get(pid);
    if (existing != null) return true;

    try {
      final snap = await _firestore.collection('projects').doc(pid).get();
      final data = snap.data();
      final now = DateTime.now();

      final project = ProjectRecord(
        id: pid,
        name: (data?['name'] ?? '').toString().trim().isEmpty
            ? 'Obra $pid'
            : data!['name'].toString().trim(),
        code: (data?['code'] ?? '').toString().trim().isEmpty
            ? pid.toUpperCase()
            : data!['code'].toString().trim(),
        isActive: data?['isActive'] != false,
        createdAt: now,
        updatedAt: now,
      );

      await _projects.put(project.id, project);
      return true;
    } catch (_) {
      return false;
    }
  }

  _AccessCodeValidationResult _validateCodeForConsumption(
    ProjectAccessCodeRecord codeRecord,
  ) {
    if (!codeRecord.active) {
      return const _AccessCodeValidationResult.invalid('Código inativo.');
    }
    if (codeRecord.isExpired) {
      return const _AccessCodeValidationResult.invalid('Código expirado.');
    }
    if (codeRecord.maxUses <= 0) {
      return const _AccessCodeValidationResult.invalid('Código inválido: limite de uso incorreto.');
    }
    if (codeRecord.remainingUses <= 0) {
      return const _AccessCodeValidationResult.invalid('Código sem usos disponíveis.');
    }
    return const _AccessCodeValidationResult.valid();
  }

  Future<DocumentReference<Map<String, dynamic>>?> _resolveRemoteCodeRefById(
    String projectId,
    String codeId,
  ) async {
    if (projectId.trim().isEmpty || codeId.trim().isEmpty) return null;
    try {
      final ref = _firestore
          .collection('projects')
          .doc(projectId)
          .collection('access_codes')
          .doc(codeId);
      final snap = await ref.get();
      if (!snap.exists) return null;
      return ref;
    } catch (_) {
      return null;
    }
  }

  Future<ProjectAccessCodeRecord> _consumeCodeRemoteAtomically({
    required DocumentReference<Map<String, dynamic>> codeRef,
  }) async {
    return _firestore.runTransaction<ProjectAccessCodeRecord>((txn) async {
      final snap = await txn.get(codeRef);
      if (!snap.exists || snap.data() == null) {
        throw StateError('Código não encontrado.');
      }

      final remote = ProjectAccessCodeRecord.fromMap({
        ...Map<String, dynamic>.from(snap.data()!),
        'id': snap.id,
      });

      final validation = _validateCodeForConsumption(remote);
      if (!validation.valid) {
        throw StateError(validation.message ?? 'Código inválido.');
      }

      final nextUsed = remote.usedCount + 1;
      final updated = remote.copyWith(
        usedCount: nextUsed,
        isActive: nextUsed < remote.maxUses,
        updatedAt: DateTime.now(),
        pendingSync: false,
        syncError: null,
      );

      txn.set(codeRef, updated.toMap(), SetOptions(merge: true));
      return updated;
    });
  }

  Future<AccessCodeConsumeResult> _consumeMasterBootstrapCode({
    required String userId,
  }) async {
    final project = await _resolveProjectForMasterBootstrap();
    if (project == null) {
      return const AccessCodeConsumeResult(
        success: false,
        message: 'Nenhuma obra disponível para liberar acesso.',
      );
    }

    final now = DateTime.now();
    final membershipId = '${userId}_${project.id}';
    final existing = _memberships.get(membershipId) ??
        _memberships.values
            .where((m) => m.userId == userId && m.projectId == project.id)
            .cast<UserProjectMembership?>()
            .firstWhere((m) => m != null, orElse: () => null);

    final membership = (existing ??
            UserProjectMembership(
              id: membershipId,
              userId: userId,
              projectId: project.id,
              role: UserProjectMembership.roleAdmin,
              isActive: true,
              createdAt: now,
              updatedAt: now,
            ))
        .copyWith(
      role: UserProjectMembership.roleAdmin,
      isActive: true,
      updatedAt: now,
    );

    await _memberships.put(membership.id, membership);

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('project_memberships')
          .doc(membership.id)
          .set(membership.toMap(), SetOptions(merge: true));
    } catch (_) {
      // Offline-first: mantém vínculo local para destravar o app.
    }

    return AccessCodeConsumeResult(
      success: true,
      message: 'Acesso administrativo liberado na obra ${project.name}.',
    );
  }

  Future<ProjectRecord?> _resolveProjectForMasterBootstrap() async {
    final contextProject = ProjectContextService.instance.currentProject;
    if (contextProject != null && contextProject.isActive) {
      return contextProject;
    }

    final activeProjects = _projects.values.where((p) => p.isActive).toList()
      ..sort((a, b) {
        final byCreatedAt = a.createdAt.compareTo(b.createdAt);
        if (byCreatedAt != 0) return byCreatedAt;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    if (activeProjects.isNotEmpty) {
      return activeProjects.first;
    }

    final fallback = await ProjectContextService.instance.ensureDefaultProject();
    return fallback;
  }

  Future<Map<String, String>> userNameByUidMap(Iterable<String> uids) async {
    final result = <String, String>{};
    final ids = uids.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();
    for (final uid in ids) {
      try {
        final doc = await _firestore.collection('users').doc(uid).get();
        final data = doc.data();
        final email = data?['email']?.toString().trim();
        final nome = data?['nome']?.toString().trim();
        if (nome != null && nome.isNotEmpty) {
          result[uid] = nome;
          continue;
        }
        if (email != null && email.isNotEmpty) {
          result[uid] = email;
        }
      } catch (_) {
        // offline-first: se falhar remoto, mantém fallback para UID curto na UI.
      }
    }
    return result;
  }

  Future<Map<String, String>> userEmailByUidMap(Iterable<String> uids) async {
    final result = <String, String>{};
    final ids = uids.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();
    for (final uid in ids) {
      try {
        final doc = await _firestore.collection('users').doc(uid).get();
        final data = doc.data();
        final email = data?['email']?.toString().trim();
        if (email != null && email.isNotEmpty) {
          result[uid] = email;
        }
      } catch (_) {
        // offline-first: mantém fallback sem e-mail explícito na UI.
      }
    }
    return result;
  }

  Future<InviteResult> inviteByEmail({
    required String email,
    required String role,
  }) async {
    final normalizedEmail = email.trim();
    final emailLower = normalizedEmail.toLowerCase();
    if (normalizedEmail.isEmpty || !normalizedEmail.contains('@')) {
      return const InviteResult(
        membershipCreated: false,
        pendingInviteCreated: false,
        message: 'Informe um email válido.',
      );
    }

    final currentProject = ProjectContextService.instance.currentProject;
    final currentProjectId = ProjectContextService.instance.currentProjectIdSync;
    final inviter = AuthService.instance.currentUser;
    if (currentProject == null || currentProjectId.trim().isEmpty || inviter == null) {
      return const InviteResult(
        membershipCreated: false,
        pendingInviteCreated: false,
        message: 'Contexto de obra/usuário indisponível.',
      );
    }

    final inviterProfile = await UserProfileService.instance.getCurrentUserProfile();
    final inviterName = inviterProfile?.nome.trim();
    final now = DateTime.now();

    try {
      final userSnap = await _firestore
          .collection('users')
          .where('email', isEqualTo: normalizedEmail)
          .limit(1)
          .get();

      if (userSnap.docs.isNotEmpty) {
        final uid = userSnap.docs.first.id;
        final existing = _memberships.values.where((m) => m.userId == uid && m.projectId == currentProjectId).toList();
        if (existing.isNotEmpty) {
          final updated = existing.first.copyWith(
            role: role,
            isActive: true,
            updatedAt: now,
          );
          await _memberships.put(updated.id, updated);
          await _firestore
              .collection('users')
              .doc(uid)
              .collection('project_memberships')
              .doc(updated.id)
              .set(updated.toMap(), SetOptions(merge: true));
          return const InviteResult(
            membershipCreated: true,
            pendingInviteCreated: false,
            message: 'Usuário já vinculado atualizado com sucesso.',
          );
        }

        final membership = UserProjectMembership(
          id: '${uid}_$currentProjectId',
          userId: uid,
          projectId: currentProjectId,
          role: role,
          isActive: true,
          createdAt: now,
          updatedAt: now,
        );
        await _memberships.put(membership.id, membership);
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('project_memberships')
            .doc(membership.id)
            .set(membership.toMap(), SetOptions(merge: true));

        return const InviteResult(
          membershipCreated: true,
          pendingInviteCreated: false,
          message: 'Usuário existente vinculado à obra com sucesso.',
        );
      }

      final inviteId = '${currentProjectId}_${emailLower.replaceAll(RegExp(r'[^a-z0-9]'), '_')}';
      final invite = ProjectInviteRecord(
        id: inviteId,
        projectId: currentProjectId,
        email: normalizedEmail,
        emailLower: emailLower,
        role: role,
        status: ProjectInviteRecord.statusPending,
        invitedByUid: inviter.uid,
        invitedByName: inviterName == null || inviterName.isEmpty ? null : inviterName,
        invitedAt: now,
        updatedAt: now,
        pendingSync: true,
        syncError: null,
      );
      await _invites.put(invite.id, invite);

      await _firestore
          .collection('projects')
          .doc(currentProjectId)
          .collection('pending_invites')
          .doc(invite.id)
          .set(invite.toMap(), SetOptions(merge: true));

      await _invites.put(
        invite.id,
        invite.copyWith(pendingSync: false, syncError: null, updatedAt: DateTime.now()),
      );

      return const InviteResult(
        membershipCreated: false,
        pendingInviteCreated: true,
        message: 'Convite pendente criado para este email.',
      );
    } catch (e) {
      final inviteId = '${currentProjectId}_${emailLower.replaceAll(RegExp(r'[^a-z0-9]'), '_')}';
      final local = ProjectInviteRecord(
        id: inviteId,
        projectId: currentProjectId,
        email: normalizedEmail,
        emailLower: emailLower,
        role: role,
        status: ProjectInviteRecord.statusPending,
        invitedByUid: inviter.uid,
        invitedByName: inviterName == null || inviterName.isEmpty ? null : inviterName,
        invitedAt: now,
        updatedAt: now,
        pendingSync: true,
        syncError: e.toString(),
      );
      await _invites.put(local.id, local);
      return const InviteResult(
        membershipCreated: false,
        pendingInviteCreated: true,
        message: 'Convite salvo localmente como pendente de sincronização.',
      );
    }
  }

  Future<int> applyPendingInvitesForEmail({
    required String userId,
    required String email,
  }) async {
    final normalizedEmail = email.trim();
    final emailLower = normalizedEmail.toLowerCase();
    if (userId.trim().isEmpty || emailLower.isEmpty) return 0;

    final now = DateTime.now();
    var acceptedCount = 0;

    final localPending = _invites.values
        .where(
          (invite) =>
              invite.status == ProjectInviteRecord.statusPending &&
              invite.emailLower == emailLower,
        )
        .toList();

    for (final invite in localPending) {
      final membershipId = '${userId}_${invite.projectId}';
      final existingMembership = _memberships.get(membershipId) ??
          _memberships.values
              .where((m) => m.userId == userId && m.projectId == invite.projectId)
              .cast<UserProjectMembership?>()
              .firstWhere((m) => m != null, orElse: () => null);

      final membership = (existingMembership ??
              UserProjectMembership(
                id: membershipId,
                userId: userId,
                projectId: invite.projectId,
                role: invite.role,
                isActive: true,
                createdAt: now,
                updatedAt: now,
              ))
          .copyWith(
        role: invite.role,
        isActive: true,
        updatedAt: now,
      );

      await _memberships.put(membership.id, membership);

      final accepted = invite.copyWith(
        status: ProjectInviteRecord.statusAccepted,
        acceptedByUid: userId,
        acceptedAt: now,
        updatedAt: now,
        pendingSync: true,
        syncError: null,
      );
      await _invites.put(accepted.id, accepted);
      acceptedCount++;

      try {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('project_memberships')
            .doc(membership.id)
            .set(membership.toMap(), SetOptions(merge: true));

        await _firestore
            .collection('projects')
            .doc(invite.projectId)
            .collection('pending_invites')
            .doc(invite.id)
            .set(accepted.toMap(), SetOptions(merge: true));

        await _invites.put(
          accepted.id,
          accepted.copyWith(
            pendingSync: false,
            syncError: null,
            updatedAt: DateTime.now(),
          ),
        );
      } catch (e) {
        await _invites.put(
          accepted.id,
          accepted.copyWith(
            pendingSync: true,
            syncError: e.toString(),
            updatedAt: DateTime.now(),
          ),
        );
      }
    }

    try {
      final remotePending = await _firestore
          .collectionGroup('pending_invites')
          .where('emailLower', isEqualTo: emailLower)
          .where('status', isEqualTo: ProjectInviteRecord.statusPending)
          .get();

      for (final doc in remotePending.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        final invite = ProjectInviteRecord.fromMap({
          ...data,
          'id': (data['id']?.toString().isNotEmpty == true) ? data['id'] : doc.id,
        });

        final alreadyAccepted = _invites.get(invite.id)?.status == ProjectInviteRecord.statusAccepted;
        if (alreadyAccepted) continue;

        final membershipId = '${userId}_${invite.projectId}';
        final membership = UserProjectMembership(
          id: membershipId,
          userId: userId,
          projectId: invite.projectId,
          role: invite.role,
          isActive: true,
          createdAt: now,
          updatedAt: now,
        );
        await _memberships.put(membership.id, membership);
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('project_memberships')
            .doc(membership.id)
            .set(membership.toMap(), SetOptions(merge: true));

        final accepted = invite.copyWith(
          status: ProjectInviteRecord.statusAccepted,
          acceptedByUid: userId,
          acceptedAt: now,
          updatedAt: now,
          pendingSync: false,
          syncError: null,
        );
        await _invites.put(accepted.id, accepted);
        await doc.reference.set(accepted.toMap(), SetOptions(merge: true));
        acceptedCount++;
      }
    } catch (_) {
      // Offline-first: mantém o que foi possível aplicar localmente.
    }

    return acceptedCount;
  }
}

