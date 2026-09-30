// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/foundation.dart';

import 'app_update_service.dart';

AppUpdateService getAppUpdateService() => _WebAppUpdateService.instance;

class _WebAppUpdateService extends ChangeNotifier implements AppUpdateService {
  _WebAppUpdateService._() {
    unawaited(checkNow());
    _timer = Timer.periodic(const Duration(minutes: 5), (_) {
      unawaited(checkNow());
    });
    _onlineSubscription = html.window.onOnline.listen((_) {
      unawaited(checkNow());
    });
  }

  static final _WebAppUpdateService instance = _WebAppUpdateService._();

  Timer? _timer;
  StreamSubscription<html.Event>? _onlineSubscription;
  String? _initialBuildId;
  bool _checking = false;
  bool _updateAvailable = false;

  @override
  bool get updateAvailable => _updateAvailable;

  @override
  String get updateSubtitle =>
      'Há uma versão nova do Obra Check pronta para carregar.';

  @override
  String get updateActionLabel => 'Atualizar';

  @override
  Future<void> checkNow() async {
    if (_checking) return;
    _checking = true;
    try {
      final latest = await _fetchLatestBuildId();
      if (latest == null || latest.isEmpty) return;

      _initialBuildId ??= latest;
      final hasUpdate = latest != _initialBuildId;
      if (_updateAvailable != hasUpdate) {
        _updateAvailable = hasUpdate;
        notifyListeners();
      }
    } catch (_) {
      // Falhas de rede sao esperadas em campo; a proxima tentativa reavalia.
    } finally {
      _checking = false;
    }
  }

  Future<String?> _fetchLatestBuildId() async {
    final uri = Uri.base.resolve('.last_build_id');
    final busted = uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        'v': DateTime.now().millisecondsSinceEpoch.toString(),
      },
    );
    final response = await html.HttpRequest.request(
      busted.toString(),
      method: 'GET',
      requestHeaders: const {'Cache-Control': 'no-cache', 'Pragma': 'no-cache'},
    );
    if (response.status != 200 && response.status != 0) return null;
    return response.responseText?.trim();
  }

  @override
  Future<void> applyUpdate() async {
    html.window.location.reload();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _onlineSubscription?.cancel();
    super.dispose();
  }
}
