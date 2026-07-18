import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/company_record.dart';
import '../models/diary_record.dart';
import '../models/inspection_record.dart';
import '../models/service_record.dart';
import 'auth_service.dart';
import 'cloud_sync_service.dart';
import 'internet_connectivity_service.dart';
import 'platform_service.dart';
import 'project_context_service.dart';
import '../utils/project_identity.dart';
import '../utils/project_scope.dart';

enum SyncErrorCategory {
  none,
  internet,
  authentication,
  noProject,
  photo,
  push,
  pull,
  unknown,
}

enum SyncVisualStatus { offline, syncing, error, pending, synced }

class SyncPendingSnapshot {
  const SyncPendingSnapshot({
    required this.inspections,
    required this.photos,
    required this.services,
    required this.companies,
    required this.diaries,
    required this.equipments,
    required this.movements,
    required this.deletes,
  });

  const SyncPendingSnapshot.zero()
    : inspections = 0,
      photos = 0,
      services = 0,
      companies = 0,
      diaries = 0,
      equipments = 0,
      movements = 0,
      deletes = 0;

  final int inspections;
  final int photos;
  final int services;
  final int companies;
  final int diaries;
  final int equipments;
  final int movements;
  final int deletes;

  int get total =>
      inspections +
      photos +
      services +
      companies +
      diaries +
      equipments +
      movements +
      deletes;
}

class SyncOrchestratorState {
  const SyncOrchestratorState({
    required this.isSyncing,
    required this.isOnline,
    required this.pending,
    required this.lastSyncAt,
    required this.lastError,
    required this.lastErrorCategory,
    required this.activeRunId,
    required this.lastTrigger,
  });

  const SyncOrchestratorState.initial()
    : isSyncing = false,
      isOnline = false,
      pending = const SyncPendingSnapshot.zero(),
      lastSyncAt = null,
      lastError = null,
      lastErrorCategory = SyncErrorCategory.none,
      activeRunId = null,
      lastTrigger = null;

  final bool isSyncing;
  final bool isOnline;
  final SyncPendingSnapshot pending;
  final DateTime? lastSyncAt;
  final String? lastError;
  final SyncErrorCategory lastErrorCategory;
  final String? activeRunId;
  final String? lastTrigger;

  SyncVisualStatus get visualStatus {
    if (!isOnline) return SyncVisualStatus.offline;
    if (isSyncing) return SyncVisualStatus.syncing;
    if (lastError != null && lastError!.trim().isNotEmpty) {
      return SyncVisualStatus.error;
    }
    if (pending.total > 0) return SyncVisualStatus.pending;
    return SyncVisualStatus.synced;
  }

  SyncOrchestratorState copyWith({
    bool? isSyncing,
    bool? isOnline,
    SyncPendingSnapshot? pending,
    DateTime? lastSyncAt,
    String? lastError,
    bool clearLastError = false,
    SyncErrorCategory? lastErrorCategory,
    bool clearLastErrorCategory = false,
    String? activeRunId,
    String? lastTrigger,
  }) {
    return SyncOrchestratorState(
      isSyncing: isSyncing ?? this.isSyncing,
      isOnline: isOnline ?? this.isOnline,
      pending: pending ?? this.pending,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
      lastErrorCategory: clearLastErrorCategory
          ? SyncErrorCategory.none
          : (lastErrorCategory ?? this.lastErrorCategory),
      activeRunId: activeRunId,
      lastTrigger: lastTrigger ?? this.lastTrigger,
    );
  }
}

class SyncExecutionResult {
  const SyncExecutionResult({
    required this.executed,
    required this.success,
    required this.message,
    required this.runId,
    required this.errorCategory,
    this.counters,
  });

  final bool executed;
  final bool success;
  final String message;
  final String runId;
  final SyncErrorCategory errorCategory;
  final SyncCounters? counters;
}

class SyncHistoryEntry {
  const SyncHistoryEntry({
    required this.runId,
    required this.trigger,
    required this.manual,
    required this.requestedAt,
    required this.startedAt,
    required this.finishedAt,
    required this.executed,
    required this.success,
    required this.errorCategory,
    required this.message,
    required this.pendingAfter,
    required this.counters,
  });

  final String runId;
  final String trigger;
  final bool manual;
  final DateTime requestedAt;
  final DateTime? startedAt;
  final DateTime finishedAt;
  final bool executed;
  final bool success;
  final SyncErrorCategory errorCategory;
  final String message;
  final SyncPendingSnapshot pendingAfter;
  final SyncCounters? counters;
}

class SyncPendingSummaryFormatter {
  static String short(SyncPendingSnapshot pending) {
    if (pending.total <= 0) return 'Sem pendências';
    final lines = operationalLines(pending);
    if (lines.isEmpty) return 'Sem pendências';
    return lines.take(2).join(' • ');
  }

  static List<String> operationalLines(SyncPendingSnapshot pending) {
    final result = <String>[];
    if (pending.photos > 0) {
      result.add(
        '${pending.photos} ${pending.photos == 1 ? 'foto pendente de envio' : 'fotos pendentes de envio'}',
      );
    }
    if (pending.inspections > 0) {
      result.add(
        '${pending.inspections} ${pending.inspections == 1 ? 'inspeção aguardando sincronização' : 'inspeções aguardando sincronização'}',
      );
    }
    if (pending.diaries > 0) {
      result.add(
        '${pending.diaries} ${pending.diaries == 1 ? 'diário pendente' : 'diários pendentes'}',
      );
    }
    if (pending.services > 0) {
      result.add(
        '${pending.services} ${pending.services == 1 ? 'serviço pendente' : 'serviços pendentes'}',
      );
    }
    if (pending.companies > 0) {
      result.add(
        '${pending.companies} ${pending.companies == 1 ? 'empresa pendente' : 'empresas pendentes'}',
      );
    }
    if (pending.equipments > 0) {
      result.add(
        '${pending.equipments} ${pending.equipments == 1 ? 'equipamento pendente' : 'equipamentos pendentes'}',
      );
    }
    if (pending.movements > 0) {
      result.add(
        '${pending.movements} ${pending.movements == 1 ? 'movimentação pendente' : 'movimentações pendentes'}',
      );
    }
    if (result.isEmpty) result.add('Sem pendências');
    return result;
  }
}

class _PendingRerunRequest {
  const _PendingRerunRequest({
    required this.trigger,
    required this.manual,
    required this.requestedAt,
  });

  final String trigger;
  final bool manual;
  final DateTime requestedAt;
}

class SyncOrchestrator {
  SyncOrchestrator._();

  static final SyncOrchestrator instance = SyncOrchestrator._();

  static const Duration _timerInterval = Duration(minutes: 5);
  static const Duration _autoCooldown = Duration(seconds: 25);
  static const int _historyLimit = 10;

  final ValueNotifier<SyncOrchestratorState> stateNotifier = ValueNotifier(
    const SyncOrchestratorState.initial(),
  );

  Timer? _timer;
  bool _started = false;
  int _runCounter = 0;
  DateTime? _lastAutoSyncFinishedAt;
  String? _lastAutoSyncTrigger;
  _PendingRerunRequest? _pendingRerun;
  final List<SyncHistoryEntry> _history = <SyncHistoryEntry>[];
  Timer? _connectivityPollTimer;

  List<SyncHistoryEntry> get history => List.unmodifiable(_history);

  Future<void> _checkConnectivityAndSync() async {
    final internet = await InternetConnectivityService.instance
        .hasRealInternet();
    final wasOffline = stateNotifier.value.isOnline;
    stateNotifier.value = stateNotifier.value.copyWith(
      isOnline: internet.hasInternet,
    );
    if (wasOffline && internet.hasInternet) {
      unawaited(requestSync(trigger: 'internet_restored', manual: false));
    }
  }

  void start() {
    if (_started) return;
    _started = true;

    _timer?.cancel();
    _timer = Timer.periodic(_timerInterval, (_) {
      unawaited(requestSync(trigger: 'timer_5m', manual: false));
    });

    _connectivityPollTimer?.cancel();
    _connectivityPollTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      unawaited(_checkConnectivityAndSync());
    });
    // Aguarda 4s antes da primeira verificação para dar tempo ao _loadInitialData
    // (refreshMembershipsForCurrentUser + hydrateCurrentProject) de concluir.
    Timer(const Duration(seconds: 4), () {
      if (_started) unawaited(_checkConnectivityAndSync());
    });

    unawaited(refreshPendingSnapshot());
  }

  void stop() {
    if (!_started) return;
    _started = false;
    _timer?.cancel();
    _timer = null;
    _connectivityPollTimer?.cancel();
    _connectivityPollTimer = null;
  }

  Future<void> refreshPendingSnapshot() async {
    final pending = _computePendingSnapshot();
    stateNotifier.value = stateNotifier.value.copyWith(pending: pending);
  }

  Future<SyncExecutionResult> requestManualSync({
    String trigger = 'manual',
  }) async {
    return _requestSyncInternal(
      trigger: trigger,
      manual: true,
      requestedAt: DateTime.now(),
      fromRerun: false,
    );
  }

  Future<SyncExecutionResult> requestSync({
    required String trigger,
    required bool manual,
  }) async {
    return _requestSyncInternal(
      trigger: trigger,
      manual: manual,
      requestedAt: DateTime.now(),
      fromRerun: false,
    );
  }

  Future<SyncExecutionResult> _requestSyncInternal({
    required String trigger,
    required bool manual,
    required DateTime requestedAt,
    required bool fromRerun,
  }) async {
    final runId = _nextRunId();

    if (stateNotifier.value.isSyncing) {
      if (!fromRerun && _shouldQueueRerun(trigger: trigger, manual: manual)) {
        _pendingRerun = _PendingRerunRequest(
          trigger: trigger,
          manual: manual,
          requestedAt: requestedAt,
        );
        _log(
          runId,
          '[COOLDOWN] rerun_queued trigger=$trigger manual=$manual reason=sync_in_progress',
        );
      }
      final pending = _computePendingSnapshot();
      stateNotifier.value = stateNotifier.value.copyWith(pending: pending);
      final message = _pendingRerun == null
          ? 'Sincronização já em andamento.'
          : 'Sincronização em andamento. Nova tentativa foi agendada.';
      _log(runId, 'skip reason=already_syncing trigger=$trigger');
      final result = SyncExecutionResult(
        executed: false,
        success: true,
        message: message,
        runId: runId,
        errorCategory: SyncErrorCategory.none,
      );
      _appendHistory(
        SyncHistoryEntry(
          runId: runId,
          trigger: trigger,
          manual: manual,
          requestedAt: requestedAt,
          startedAt: null,
          finishedAt: DateTime.now(),
          executed: false,
          success: true,
          errorCategory: SyncErrorCategory.none,
          message: message,
          pendingAfter: pending,
          counters: null,
        ),
      );
      return result;
    }

    if (!manual && _isAutoTriggerCooldownActive(trigger: trigger)) {
      final pending = _computePendingSnapshot();
      stateNotifier.value = stateNotifier.value.copyWith(pending: pending);
      final remaining =
          _autoCooldown.inSeconds -
          DateTime.now().difference(_lastAutoSyncFinishedAt!).inSeconds;
      final message =
          'Gatilho automático ignorado por cooldown (${remaining.clamp(0, _autoCooldown.inSeconds)}s).';
      _log(
        runId,
        '[COOLDOWN] ignored trigger=$trigger manual=$manual lastTrigger=$_lastAutoSyncTrigger',
      );
      final result = SyncExecutionResult(
        executed: false,
        success: true,
        message: message,
        runId: runId,
        errorCategory: SyncErrorCategory.none,
      );
      _appendHistory(
        SyncHistoryEntry(
          runId: runId,
          trigger: trigger,
          manual: manual,
          requestedAt: requestedAt,
          startedAt: null,
          finishedAt: DateTime.now(),
          executed: false,
          success: true,
          errorCategory: SyncErrorCategory.none,
          message: message,
          pendingAfter: pending,
          counters: null,
        ),
      );
      return result;
    }

    if (!ProjectContextService.instance.hasProjectAccessForCurrentUserSync) {
      final pending = _computePendingSnapshot();
      stateNotifier.value = stateNotifier.value.copyWith(pending: pending);
      final message = 'Sincronização indisponível: sem obra ativa.';
      _log(runId, 'skip reason=no_project_access trigger=$trigger');
      final result = SyncExecutionResult(
        executed: false,
        success: false,
        message: message,
        runId: runId,
        errorCategory: SyncErrorCategory.noProject,
      );
      _appendHistory(
        SyncHistoryEntry(
          runId: runId,
          trigger: trigger,
          manual: manual,
          requestedAt: requestedAt,
          startedAt: null,
          finishedAt: DateTime.now(),
          executed: false,
          success: false,
          errorCategory: SyncErrorCategory.noProject,
          message: message,
          pendingAfter: pending,
          counters: null,
        ),
      );
      return result;
    }

    final startedAt = DateTime.now();
    if (!manual) {
      _lastAutoSyncTrigger = trigger;
    }

    stateNotifier.value = stateNotifier.value.copyWith(
      isSyncing: true,
      activeRunId: runId,
      lastTrigger: trigger,
      clearLastError: true,
      clearLastErrorCategory: true,
    );

    _log(runId, 'start trigger=$trigger manual=$manual');

    if (PlatformService.instance.isWeb) {
      final internet = await InternetConnectivityService.instance
          .hasRealInternet();
      if (!internet.hasInternet) {
        final message = 'Web: conexão com internet necessária para operar';
        final pending = _computePendingSnapshot();
        stateNotifier.value = stateNotifier.value.copyWith(
          isSyncing: false,
          activeRunId: null,
          lastError: message,
          lastErrorCategory: SyncErrorCategory.internet,
          pending: pending,
        );
        _log(runId, 'blocked_web reason="${internet.reason}"');
        final result = SyncExecutionResult(
          executed: false,
          success: false,
          message: message,
          runId: runId,
          errorCategory: SyncErrorCategory.internet,
        );
        _appendHistory(
          SyncHistoryEntry(
            runId: runId,
            trigger: trigger,
            manual: manual,
            requestedAt: requestedAt,
            startedAt: startedAt,
            finishedAt: DateTime.now(),
            executed: false,
            success: false,
            errorCategory: SyncErrorCategory.internet,
            message: message,
            pendingAfter: pending,
            counters: null,
          ),
        );
        return result;
      }
    }

    if (PlatformService.instance.isMobile) {
      final internet = await InternetConnectivityService.instance
          .hasRealInternet();
      stateNotifier.value = stateNotifier.value.copyWith(
        isOnline: internet.hasInternet,
      );
    }

    try {
      await AuthService.instance.ensureAnonymousSession();
      final availability = await CloudSyncService.instance.checkAvailability();
      if (!availability.available) {
        final category = _categorizeAvailabilityReason(availability.reason);
        final message = _buildErrorMessage(category, availability.reason);
        if (!manual) _lastAutoSyncFinishedAt = DateTime.now();
        final pending = _computePendingSnapshot();
        stateNotifier.value = stateNotifier.value.copyWith(
          isSyncing: false,
          activeRunId: null,
          lastError: message,
          lastErrorCategory: category,
          pending: pending,
        );
        _log(
          runId,
          'blocked reason="${availability.reason}" category=$category',
        );
        final result = SyncExecutionResult(
          executed: false,
          success: false,
          message: message,
          runId: runId,
          errorCategory: category,
        );
        _appendHistory(
          SyncHistoryEntry(
            runId: runId,
            trigger: trigger,
            manual: manual,
            requestedAt: requestedAt,
            startedAt: startedAt,
            finishedAt: DateTime.now(),
            executed: false,
            success: false,
            errorCategory: category,
            message: message,
            pendingAfter: pending,
            counters: null,
          ),
        );
        unawaited(_consumePendingRerunIfAny());
        return result;
      }

      final counters = await CloudSyncService.instance.syncNow();
      final pending = _computePendingSnapshot();
      final now = DateTime.now();
      if (!manual) _lastAutoSyncFinishedAt = now;

      stateNotifier.value = stateNotifier.value.copyWith(
        isSyncing: false,
        activeRunId: null,
        lastSyncAt: now,
        pending: pending,
      );

      final message = _buildSuccessMessage(counters);
      _log(
        runId,
        'done trigger=$trigger inspections=${counters.inspections} services=${counters.services} '
        'companies=${counters.companies} diaries=${counters.diaries} equipments=${counters.equipments} '
        'movements=${counters.movements} photoSynced=${counters.photoSynced} '
        'photoPendingAfter=${counters.photoPendingAfter}',
      );

      final result = SyncExecutionResult(
        executed: true,
        success: true,
        message: message,
        runId: runId,
        errorCategory: SyncErrorCategory.none,
        counters: counters,
      );
      _appendHistory(
        SyncHistoryEntry(
          runId: runId,
          trigger: trigger,
          manual: manual,
          requestedAt: requestedAt,
          startedAt: startedAt,
          finishedAt: now,
          executed: true,
          success: true,
          errorCategory: SyncErrorCategory.none,
          message: message,
          pendingAfter: pending,
          counters: counters,
        ),
      );
      unawaited(_consumePendingRerunIfAny());
      return result;
    } catch (e) {
      final pending = _computePendingSnapshot();
      final category = _categorizeException(e);
      final error = _buildErrorMessage(category, e.toString());
      if (!manual) _lastAutoSyncFinishedAt = DateTime.now();
      stateNotifier.value = stateNotifier.value.copyWith(
        isSyncing: false,
        activeRunId: null,
        lastError: error,
        lastErrorCategory: category,
        pending: pending,
      );
      _log(runId, 'error trigger=$trigger category=$category error=$e');
      final result = SyncExecutionResult(
        executed: true,
        success: false,
        message: error,
        runId: runId,
        errorCategory: category,
      );
      _appendHistory(
        SyncHistoryEntry(
          runId: runId,
          trigger: trigger,
          manual: manual,
          requestedAt: requestedAt,
          startedAt: startedAt,
          finishedAt: DateTime.now(),
          executed: true,
          success: false,
          errorCategory: category,
          message: error,
          pendingAfter: pending,
          counters: null,
        ),
      );
      unawaited(_consumePendingRerunIfAny());
      return result;
    }
  }

  bool _isAutoTriggerCooldownActive({required String trigger}) {
    if (_lastAutoSyncFinishedAt == null) return false;
    if (!_isCoalescedAutoTrigger(trigger)) return false;
    final elapsed = DateTime.now().difference(_lastAutoSyncFinishedAt!);
    return elapsed < _autoCooldown;
  }

  bool _isCoalescedAutoTrigger(String trigger) {
    return trigger == 'timer_5m' ||
        trigger == 'internet_restored' ||
        trigger.contains('resume') ||
        trigger.contains('foreground');
  }

  bool _shouldQueueRerun({required String trigger, required bool manual}) {
    if (manual) return true;
    if (!_isCoalescedAutoTrigger(trigger)) return false;
    if (_pendingRerun == null) return true;
    if (_pendingRerun!.manual) return false;
    return _pendingRerun!.trigger != trigger;
  }

  Future<void> _consumePendingRerunIfAny() async {
    if (stateNotifier.value.isSyncing) return;
    final next = _pendingRerun;
    if (next == null) return;
    _pendingRerun = null;

    if (!next.manual && _isAutoTriggerCooldownActive(trigger: next.trigger)) {
      _log(
        _nextRunId(),
        '[COOLDOWN] rerun_discarded trigger=${next.trigger} reason=cooldown_active',
      );
      return;
    }

    _log(
      _nextRunId(),
      '[COOLDOWN] rerun_execute trigger=${next.trigger} manual=${next.manual}',
    );
    await _requestSyncInternal(
      trigger: '${next.trigger}:rerun',
      manual: next.manual,
      requestedAt: next.requestedAt,
      fromRerun: true,
    );
  }

  SyncPendingSnapshot _computePendingSnapshot() {
    final inspectionsBox = Hive.box<InspectionRecord>('inspections');
    final servicesBox = Hive.box<ServiceRecord>('services');
    final companiesBox = Hive.box<CompanyRecord>('companies');
    final diariesBox = Hive.box<DiaryRecord>('diaries');
    final equipmentsBox = Hive.box('equipments');
    final movementsBox = Hive.box('equipment_movements');
    final currentProjectId = currentProjectIdOrNull(
      ProjectContextService.instance.currentProjectIdSync,
    );
    if (currentProjectId == null) {
      return const SyncPendingSnapshot.zero();
    }

    var inspections = 0;
    var photos = 0;
    var deletes = 0;

    for (final record in inspectionsBox.values) {
      if (!matchesActiveProject(
        activeProjectId: currentProjectId,
        recordProjectId: record.projectId,
        recordObra: record.obra,
      )) {
        continue;
      }
      if (record.deleted && record.pendingSync) {
        deletes++;
      }
      if (record.pendingSync || record.hasPendingPhotoSync) {
        inspections++;
      }
      for (final item in record.itens) {
        photos += item.photos.where((photo) => photo.pendingSync).length;
      }
    }

    var services = 0;
    for (final service in servicesBox.values) {
      if (!matchesActiveProject(
        activeProjectId: currentProjectId,
        recordProjectId: service.projectId,
        recordObra: service.obra,
      )) {
        continue;
      }
      if (service.pendingSync) services++;
      if (service.deleted && service.pendingSync) deletes++;
    }

    var companies = 0;
    for (final company in companiesBox.values) {
      if (!matchesActiveProject(
        activeProjectId: currentProjectId,
        recordProjectId: company.projectId,
      )) {
        continue;
      }
      if (company.pendingSync) companies++;
      if (company.deleted && company.pendingSync) deletes++;
    }

    var diaries = 0;
    for (final diary in diariesBox.values) {
      if (!matchesActiveProject(
        activeProjectId: currentProjectId,
        recordProjectId: diary.projectId,
        recordObra: diary.obra,
      )) {
        continue;
      }
      if (diary.pendingSync) diaries++;
      if (diary.deleted && diary.pendingSync) deletes++;
    }

    var equipments = 0;
    for (final key in equipmentsBox.keys) {
      final raw = equipmentsBox.get(key);
      if (raw is! Map) continue;
      if (!matchesActiveProject(
        activeProjectId: currentProjectId,
        recordProjectId: inferProjectId(
          projectId: raw['projectId']?.toString(),
          obra: raw['obra']?.toString(),
        ),
        recordObra: raw['obra']?.toString(),
      )) {
        continue;
      }
      if (raw['pendingSync'] == true) equipments++;
      if (raw['deleted'] == true && raw['pendingSync'] == true) deletes++;
    }

    var movements = 0;
    for (final key in movementsBox.keys) {
      final raw = movementsBox.get(key);
      if (raw is! Map) continue;
      if (!matchesActiveProject(
        activeProjectId: currentProjectId,
        recordProjectId: inferProjectId(
          projectId: raw['projectId']?.toString(),
          obra: raw['obra']?.toString(),
        ),
        recordObra: raw['obra']?.toString(),
      )) {
        continue;
      }
      if (raw['pendingSync'] == true) movements++;
      if (raw['deleted'] == true && raw['pendingSync'] == true) deletes++;
    }

    return SyncPendingSnapshot(
      inspections: inspections,
      photos: photos,
      services: services,
      companies: companies,
      diaries: diaries,
      equipments: equipments,
      movements: movements,
      deletes: deletes,
    );
  }

  String _buildSuccessMessage(SyncCounters counters) {
    return 'OK • Inspeções: ${counters.inspections} • Serviços: ${counters.services} • '
        'Empreiteiros: ${counters.companies} • Diários: ${counters.diaries} • '
        'Equip.: ${counters.equipments} • Mov.: ${counters.movements} • '
        'Fotos: +${counters.photoSynced} / pendentes ${counters.photoPendingAfter}';
  }

  void _appendHistory(SyncHistoryEntry entry) {
    _history.insert(0, entry);
    if (_history.length > _historyLimit) {
      _history.removeRange(_historyLimit, _history.length);
    }
    _log(
      entry.runId,
      '[HISTORY] appended success=${entry.success} executed=${entry.executed} trigger=${entry.trigger} pending=${entry.pendingAfter.total}',
    );
  }

  SyncErrorCategory _categorizeAvailabilityReason(String reason) {
    final normalized = reason.toLowerCase();
    if (normalized.contains('obra ativa') || normalized.contains('sem obra')) {
      return SyncErrorCategory.noProject;
    }
    if (normalized.contains('internet') ||
        normalized.contains('offline') ||
        normalized.contains('conex')) {
      return SyncErrorCategory.internet;
    }
    if (normalized.contains('auth') ||
        normalized.contains('sess') ||
        normalized.contains('login') ||
        normalized.contains('token')) {
      return SyncErrorCategory.authentication;
    }
    return SyncErrorCategory.unknown;
  }

  SyncErrorCategory _categorizeException(Object error) {
    final normalized = error.toString().toLowerCase();
    if (normalized.contains('internet') ||
        normalized.contains('offline') ||
        normalized.contains('network') ||
        normalized.contains('socket')) {
      return SyncErrorCategory.internet;
    }
    if (normalized.contains('auth') ||
        normalized.contains('permission-denied') ||
        normalized.contains('unauth') ||
        normalized.contains('token') ||
        normalized.contains('login')) {
      return SyncErrorCategory.authentication;
    }
    if (normalized.contains('photo') ||
        normalized.contains('foto') ||
        normalized.contains('storage')) {
      return SyncErrorCategory.photo;
    }
    if (normalized.contains('pull')) return SyncErrorCategory.pull;
    if (normalized.contains('push') || normalized.contains('upload')) {
      return SyncErrorCategory.push;
    }
    return SyncErrorCategory.unknown;
  }

  String _buildErrorMessage(SyncErrorCategory category, String original) {
    final clean = original.trim().isEmpty
        ? 'Erro desconhecido.'
        : original.trim();
    switch (category) {
      case SyncErrorCategory.internet:
        return 'Erro de internet: verifique sua conexão e tente novamente. ($clean)';
      case SyncErrorCategory.authentication:
        return 'Erro de autenticação: faça login novamente para sincronizar. ($clean)';
      case SyncErrorCategory.noProject:
        return 'Erro de obra ativa: selecione uma obra antes de sincronizar. ($clean)';
      case SyncErrorCategory.photo:
        return 'Erro de fotos: falha ao enviar/validar anexos de imagem. ($clean)';
      case SyncErrorCategory.push:
        return 'Erro de push: falha ao enviar dados locais para a nuvem. ($clean)';
      case SyncErrorCategory.pull:
        return 'Erro de pull: falha ao baixar atualizações remotas. ($clean)';
      case SyncErrorCategory.none:
      case SyncErrorCategory.unknown:
        return 'Erro de sincronização: $clean';
    }
  }

  String _nextRunId() {
    _runCounter++;
    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    return 'sync_${stamp}_${_runCounter.toString().padLeft(4, '0')}';
  }

  void _log(String runId, String message) {
    debugPrint('[SYNC_ORCH][$runId] $message');
  }
}
