import 'app_update_service_stub.dart'
    if (dart.library.html) 'app_update_service_web.dart';

abstract class AppUpdateService {
  static AppUpdateService get instance => getAppUpdateService();

  bool get updateAvailable;

  void addListener(void Function() listener);

  void removeListener(void Function() listener);

  Future<void> checkNow();

  Future<void> applyUpdate();
}
