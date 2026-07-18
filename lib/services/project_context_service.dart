import 'package:hive/hive.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/scheduler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/project_record.dart';
import '../models/user_project_membership.dart';
import '../models/project_access_code_record.dart';
import '../utils/project_identity.dart';
import 'auth_service.dart';

class ProjectContextService extends ChangeNotifier {
  ProjectContextService._();

  static final ProjectContextService instance = ProjectContextService._();

  static const String _prefCurrentProjectId = 'current_project_id';
  static const String _prefCurrentProjectCode = 'current_project_code';

  Box get _prefs => Hive.box('prefs');
  Box<ProjectRecord> get _projects => Hive.box<ProjectRecord>('projects');
  Box<UserProjectMembership> get _memberships =>
      Hive.box<UserProjectMembership>('user_project_memberships');
  Box<ProjectAccessCodeRecord> get _accessCodes =>
      Hive.box<ProjectAccessCodeRecord>('project_access_codes');
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ProjectRecord? _currentProject;

  void _notifySafely() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
      return;
    }
    notifyListeners();
  }

  ProjectRecord? get currentProject => _currentProject;
  String get currentProjectIdSync => _currentProject?.id ?? '';
  String get currentProjectCodeSync => _currentProject?.code ?? '';
  String get currentProjectNameSync => _currentProject?.name ?? 'Sem obra vinculada';
  String _currentUserId = '';

  String get currentUserRoleInProjectSync {
    final userId = _currentUserId.trim();
    if (userId.isEmpty) return UserProjectMembership.roleViewer;
    final role = membershipForUserProject(
      userId: userId,
      projectId: currentProjectIdSync,
    )
        ?.role;
    return role ?? UserProjectMembership.roleViewer;
  }

  bool get hasProjectAccessForCurrentUserSync {
    return availableProjectsForCurrentUserSync().isNotEmpty;
  }

  bool get canCreateProjectSync {
    return UserProjectMembership.canManageProject(currentUserRoleInProjectSync);
  }

  bool get canEditRegistrySync {
    return UserProjectMembership.canManageProject(currentUserRoleInProjectSync);
  }

  bool get canFinalizeInspectionSync {
    return UserProjectMembership.canInspect(currentUserRoleInProjectSync);
  }

  bool get canOpenNcSync {
    return UserProjectMembership.canInspect(currentUserRoleInProjectSync);
  }

  bool get canManageUsersSync {
    return currentUserRoleInProjectSync == UserProjectMembership.roleAdmin;
  }

  UserProjectMembership? membershipForUserProject({
    required String userId,
    required String projectId,
  }) {
    final uid = userId.trim();
    final pid = projectId.trim();
    if (uid.isEmpty || pid.isEmpty) return null;

    for (final membership in _memberships.values) {
      if (!membership.isActive) continue;
      if (membership.userId != uid) continue;
      if (membership.projectId != pid) continue;
      return membership;
    }
    return null;
  }

  List<ProjectRecord> availableProjectsForCurrentUserSync() {
    final all = allProjects();
    final uid = _currentUserId.trim();

    // Compatibilidade: sem usuário autenticado, mantém legado disponível.
    if (uid.isEmpty) return all;

    final allowedIds = _memberships.values
        .where((m) => m.isActive && m.userId == uid)
        .map((m) => m.projectId)
        .toSet();

    if (allowedIds.isEmpty) {
      return const <ProjectRecord>[];
    }

    return all.where((p) => allowedIds.contains(p.id)).toList();
  }

  Future<String> getCurrentProjectId() async {
    final raw = _prefs.get(_prefCurrentProjectId)?.toString();
    final normalized = normalizeProjectId(raw);
    if (normalized.isNotEmpty) return normalized;
    return '';
  }

  Future<String> getCurrentProjectCode() async {
    final raw = _prefs.get(_prefCurrentProjectCode)?.toString().trim();
    if (raw != null && raw.isNotEmpty) return raw;
    return '';
  }

  Future<ProjectRecord> ensureDefaultProject() async {
    final now = DateTime.now();
    final existing = _projects.get(kLegacyProjectId);
    final defaultProject = existing ??
        ProjectRecord(
          id: kLegacyProjectId,
          name: kLegacyProjectName,
          code: kLegacyProjectCode,
          isActive: true,
          createdAt: now,
          updatedAt: now,
        );

    if (existing == null) {
      await _projects.put(defaultProject.id, defaultProject);
    }

    return defaultProject;
  }

  Future<void> hydrateCurrentProject() async {
    final allowed = availableProjectsForCurrentUserSync();
    final selectedId = await getCurrentProjectId();
    if (allowed.isEmpty) {
      _currentProject = null;
      await _prefs.delete(_prefCurrentProjectId);
      await _prefs.delete(_prefCurrentProjectCode);
      await _prefs.delete('obra_code');
      _notifySafely();
      return;
    }

    final selected = allowed.firstWhere(
      (project) => project.id == selectedId,
      orElse: () => allowed.first,
    );

    _currentProject = selected;
    await _prefs.put(_prefCurrentProjectId, selected.id);
    await _prefs.put(_prefCurrentProjectCode, selected.code);
    await _prefs.put('obra_code', selected.code);
    _notifySafely();
  }

  Future<void> refreshMembershipsForCurrentUser() async {
    final user = AuthService.instance.currentUser;
    _currentUserId = user?.uid ?? '';

    // Compatibilidade offline/legado: se não há user, não bloqueia projeto legado.
    if (user == null) {
      _notifySafely();
      return;
    }

    final projectIdsToFetch = <String>{};

    try {
      final membershipsSnap = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('project_memberships')
          .get();

      for (final doc in membershipsSnap.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        final rec = UserProjectMembership.fromMap({
          ...data,
          'id': data['id']?.toString().isNotEmpty == true ? data['id'] : doc.id,
          'userId': data['userId']?.toString().isNotEmpty == true ? data['userId'] : user.uid,
        });
        await _memberships.put(rec.id, rec);
        if (rec.isActive && rec.projectId.trim().isNotEmpty) {
          projectIdsToFetch.add(rec.projectId.trim());
        }
      }
    } catch (e, st) {
      // Offline-first: mantém memberships locais em caso de falha remota.
      debugPrint('[ProjectContext] refreshMemberships error: $e\n$st');
    }

    // Em dispositivo novo, o Hive local não tem registros de ProjectRecord.
    // Busca do Firestore para que hydrateCurrentProject() consiga setar obra_code.
    for (final pid in projectIdsToFetch) {
      if (_projects.containsKey(pid)) continue;
      try {
        final snap = await _firestore.collection('projects').doc(pid).get();
        final data = snap.data();
        if (data == null) continue;
        final now = DateTime.now();
        final project = ProjectRecord(
          id: pid,
          name: (data['name'] ?? '').toString().trim().isEmpty
              ? 'Obra $pid'
              : data['name'].toString().trim(),
          code: (data['code'] ?? '').toString().trim().isEmpty
              ? pid.toUpperCase()
              : data['code'].toString().trim(),
          isActive: data['isActive'] != false,
          createdAt: now,
          updatedAt: now,
        );
        await _projects.put(project.id, project);
      } catch (e) {
        debugPrint('[ProjectContext] fetchProject($pid) error: $e');
      }
    }

    _notifySafely();
  }

  List<ProjectRecord> allProjects() {
    final out = _projects.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return out;
  }

  Future<void> switchProject(String projectId) async {
    final normalized = normalizeProjectId(projectId);
    if (normalized.isEmpty) return;

    final selected = _projects.get(normalized);
    if (selected == null) return;

    final allowed = availableProjectsForCurrentUserSync().any((p) => p.id == normalized);
    if (!allowed) return;

    await _prefs.put(_prefCurrentProjectId, selected.id);
    await _prefs.put(_prefCurrentProjectCode, selected.code);
    // Compatibilidade com chave legada já usada pelo sync atual.
    await _prefs.put('obra_code', selected.code);

    _currentProject = selected;
    _notifySafely();
  }

  Future<ProjectRecord> createProject({
    required String name,
    required String code,
  }) async {
    final now = DateTime.now();
    final normalizedName = name.trim();
    final normalizedCode = code.trim().toUpperCase();
    final id = normalizedName
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');

    final projectId = id.isEmpty ? now.microsecondsSinceEpoch.toString() : id;
    final projectCode = normalizedCode.isEmpty ? 'OBRA-${now.year}' : normalizedCode;

    final project = ProjectRecord(
      id: projectId,
      name: normalizedName.isEmpty ? 'Nova obra' : normalizedName,
      code: projectCode,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );

    await _projects.put(project.id, project);
    await _ensureCurrentUserAdminMembership(project.id);
    await _createAccessCodeForProject(project.id, projectCode);
    await _persistProjectToFirestore(project);
    await switchProject(project.id);
    return project;
  }

  Future<void> _persistProjectToFirestore(ProjectRecord project) async {
    try {
      final batch = _firestore.batch();
      
      batch.set(
        _firestore.collection('projects').doc(project.id),
        project.toMap(),
      );
      
      batch.set(
        _firestore.collection('obras').doc(project.code),
        {
          'obraCode': project.code,
          'projectId': project.id,
          'name': project.name,
          'createdAt': Timestamp.fromDate(project.createdAt),
          'createdBy': _currentUserId.isNotEmpty ? _currentUserId : 'system',
          'isActive': project.isActive,
        },
        SetOptions(merge: true),
      );
      
      await batch.commit();
      debugPrint('[PROJECT] Documentos criados: projects/${project.id} e obras/${project.code}');
    } catch (e) {
      debugPrint('[PROJECT] Erro ao criar documentos no Firestore: $e');
    }
  }

  Future<void> _createAccessCodeForProject(String projectId, String projectCode) async {
    final existing = _accessCodes.values.where((c) => c.projectId == projectId && c.active).toList();
    if (existing.isNotEmpty) return;

    final now = DateTime.now();
    final userId = _currentUserId.trim();
    final code = ProjectAccessCodeRecord(
      id: 'default_${now.millisecondsSinceEpoch}',
      projectId: projectId,
      code: projectCode,
      role: UserProjectMembership.roleAdmin,
      expiresAt: null,
      maxUses: 0,
      usedCount: 0,
      isActive: true,
      createdByUid: userId.isNotEmpty ? userId : 'system',
      createdAt: now,
      updatedAt: now,
    );
    await _accessCodes.put(code.id, code);
  }

  Future<void> _ensureCurrentUserAdminMembership(String projectId) async {
    final userId = _currentUserId.trim();
    if (userId.isEmpty) return;
    final existing = membershipForUserProject(userId: userId, projectId: projectId);
    if (existing != null) return;

    final now = DateTime.now();
    final membership = UserProjectMembership(
      id: '${userId}_$projectId',
      userId: userId,
      projectId: projectId,
      role: UserProjectMembership.roleAdmin,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
    await _memberships.put(membership.id, membership);
  }
}

