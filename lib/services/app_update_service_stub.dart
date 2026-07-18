import 'app_update_service.dart';

AppUpdateService getAppUpdateService() => _NoopAppUpdateService.instance;

class _NoopAppUpdateService implements AppUpdateService {
  _NoopAppUpdateService._();

  static final _NoopAppUpdateService instance = _NoopAppUpdateService._();

  @override
  bool get updateAvailable => false;

  @override
  void addListener(void Function() listener) {}

  @override
  void removeListener(void Function() listener) {}

  @override
  Future<void> checkNow() async {}

  @override
  Future<void> applyUpdate() async {}
}
