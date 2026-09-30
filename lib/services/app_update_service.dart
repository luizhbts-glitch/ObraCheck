import 'app_update_service_mobile.dart'
    if (dart.library.html) 'app_update_service_web.dart';

abstract class AppUpdateService {
  static AppUpdateService get instance => getAppUpdateService();

  bool get updateAvailable;

  /// Texto do card de aviso — cada plataforma customiza (web recarrega na
  /// hora; mobile precisa baixar e instalar o APK manualmente).
  String get updateSubtitle;

  String get updateActionLabel;

  void addListener(void Function() listener);

  void removeListener(void Function() listener);

  Future<void> checkNow();

  Future<void> applyUpdate();
}
