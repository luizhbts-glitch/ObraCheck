import 'dart:async';

import 'package:flutter/foundation.dart';

import 'internet_connectivity_service.dart';

enum OnlineSyncPhase { idle, syncing }

class OnlineModeStatus {
  const OnlineModeStatus({
    required this.isOnline,
    required this.phase,
    required this.reason,
  });

  final bool isOnline;
  final OnlineSyncPhase phase;
  final String reason;

  OnlineModeStatus copyWith({
    bool? isOnline,
    OnlineSyncPhase? phase,
    String? reason,
  }) {
    return OnlineModeStatus(
      isOnline: isOnline ?? this.isOnline,
      phase: phase ?? this.phase,
      reason: reason ?? this.reason,
    );
  }
}

class OnlineModeService {
  OnlineModeService._();

  static final OnlineModeService instance = OnlineModeService._();

  static const Duration _pollInterval = Duration(seconds: 20);

  final ValueNotifier<OnlineModeStatus> statusNotifier = ValueNotifier(
    const OnlineModeStatus(
      isOnline: false,
      phase: OnlineSyncPhase.idle,
      reason: 'offline',
    ),
  );

  Timer? _pollTimer;
  bool _started = false;
  bool _checking = false;

  void start() {
    if (_started) return;
    _started = true;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      unawaited(refreshNow(trigger: 'poll'));
    });
    unawaited(refreshNow(trigger: 'start'));
  }

  Future<void> refreshNow({required String trigger}) async {
    if (_checking) return;
    _checking = true;
    try {
      final previous = statusNotifier.value;
      final internet = await InternetConnectivityService.instance.hasRealInternet();
      final onlineNow = internet.hasInternet;
      final next = previous.copyWith(
        isOnline: onlineNow,
        reason: internet.reason,
      );
      statusNotifier.value = next;

      final restored = !previous.isOnline && onlineNow;
      if (restored) {
        debugPrint('[ONLINE_MODE] internet restabelecida (trigger=$trigger)');
      }
    } finally {
      _checking = false;
    }
  }

  Future<void> runSyncIfOnline({required String trigger}) async {
    await refreshNow(trigger: 'pre_sync:$trigger');
    if (!statusNotifier.value.isOnline) {
      debugPrint('[ONLINE_MODE] offline, sync não executada (trigger=$trigger)');
      return;
    }
    debugPrint('[ONLINE_MODE] online, aguardando disparo do orquestrador (trigger=$trigger)');
  }
}
