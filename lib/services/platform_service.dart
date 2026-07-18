import 'package:flutter/foundation.dart';

enum AppPlatform { web, mobile }

class PlatformService {
  PlatformService._();

  static final PlatformService instance = PlatformService._();

  AppPlatform get platform => kIsWeb ? AppPlatform.web : AppPlatform.mobile;

  bool get isWeb => kIsWeb;
  bool get isMobile => !kIsWeb;

  bool get supportsOfflineStorage => isMobile;

  bool get requiresConnectivityForOperation => isWeb;
}
