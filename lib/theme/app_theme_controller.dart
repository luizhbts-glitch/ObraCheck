import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:hive/hive.dart';

enum AppThemePreference { system, light, dark }

class AppThemeController extends ChangeNotifier {
  static const String prefsKey = 'app_theme_mode';

  final Box _prefs;
  AppThemePreference _preference = AppThemePreference.system;
  bool _disposed = false;

  AppThemeController(this._prefs);

  void _notifySafely() {
    if (_disposed) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_disposed) return;
        if (!hasListeners) return;
        notifyListeners();
      });
      return;
    }
    if (!hasListeners) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  AppThemePreference get preference => _preference;

  ThemeMode get themeMode {
    switch (_preference) {
      case AppThemePreference.light:
        return ThemeMode.light;
      case AppThemePreference.dark:
        return ThemeMode.dark;
      case AppThemePreference.system:
        return ThemeMode.system;
    }
  }

  Future<void> load() async {
    final raw = (_prefs.get(prefsKey) ?? 'system').toString();
    _preference = _fromStorage(raw);
    _notifySafely();
  }

  Future<void> setPreference(AppThemePreference value) async {
    _preference = value;
    await _prefs.put(prefsKey, _toStorage(value));
    _notifySafely();
  }

  static String _toStorage(AppThemePreference value) {
    switch (value) {
      case AppThemePreference.light:
        return 'light';
      case AppThemePreference.dark:
        return 'dark';
      case AppThemePreference.system:
        return 'system';
    }
  }

  static AppThemePreference _fromStorage(String value) {
    switch (value.toLowerCase()) {
      case 'light':
        return AppThemePreference.light;
      case 'dark':
        return AppThemePreference.dark;
      default:
        return AppThemePreference.system;
    }
  }
}

class AppThemeScope extends InheritedNotifier<AppThemeController> {
  const AppThemeScope({
    super.key,
    required AppThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppThemeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppThemeScope>();
    if (scope == null || scope.notifier == null) {
      throw StateError('AppThemeScope não encontrado na árvore de widgets.');
    }
    return scope.notifier!;
  }
}

