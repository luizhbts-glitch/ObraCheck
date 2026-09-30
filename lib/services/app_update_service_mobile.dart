import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_update_service.dart';

AppUpdateService getAppUpdateService() => _MobileAppUpdateService.instance;

/// Checagem de atualização pro app instalado via APK — sem Play Store
/// (`applicationId` ainda é o padrão `com.example.*`, nunca foi publicado),
/// não existe atualização automática. Isso só avisa que tem uma versão
/// nova e abre o link de download; o usuário instala por cima manualmente
/// (Android pede confirmação de "instalar app desconhecido" de qualquer
/// forma, não tem como pular esse passo num APK avulso).
///
/// Fonte da verdade: `mobile_release.json`, estático, hospedado no mesmo
/// Firebase Hosting do app web (não usa Firestore — evita depender de cota
/// pra uma checagem que já tem esse problema recorrente em outros pontos
/// do app). Pra publicar uma atualização: gerar o APK novo, hospedar em
/// algum link acessível (ex.: `web/downloads/` do próprio projeto, que sobe
/// junto no `firebase deploy --only hosting`), e atualizar esse JSON com o
/// `buildNumber` novo (bate com o `+N` do pubspec.yaml), `versionName` e
/// `downloadUrl` apontando pro APK.
class _MobileAppUpdateService extends ChangeNotifier
    implements AppUpdateService {
  _MobileAppUpdateService._() {
    if (_supported) {
      unawaited(checkNow());
      _timer = Timer.periodic(const Duration(hours: 6), (_) {
        unawaited(checkNow());
      });
    }
  }

  static final _MobileAppUpdateService instance = _MobileAppUpdateService._();

  static const String _releaseInfoUrl =
      'https://obra-check.web.app/mobile_release.json';

  static bool get _supported {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  Timer? _timer;
  bool _checking = false;
  bool _updateAvailable = false;
  String? _downloadUrl;
  String _versionName = '';

  @override
  bool get updateAvailable => _updateAvailable;

  @override
  String get updateSubtitle => _versionName.isEmpty
      ? 'Há uma versão nova do Obra Check disponível para baixar e instalar.'
      : 'Versão $_versionName do Obra Check disponível para baixar e instalar.';

  @override
  String get updateActionLabel => 'Baixar atualização';

  @override
  Future<void> checkNow() async {
    if (!_supported || _checking) return;
    _checking = true;
    try {
      final info = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(info.buildNumber) ?? 0;

      final uri = Uri.parse(_releaseInfoUrl).replace(
        queryParameters: {
          'v': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );
      final response = await http
          .get(uri, headers: const {'Cache-Control': 'no-cache'})
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final latestBuild = (data['buildNumber'] as num?)?.toInt() ?? 0;
      final url = (data['downloadUrl'] as String?)?.trim() ?? '';
      _versionName = (data['versionName'] as String?)?.trim() ?? '';
      _downloadUrl = url;

      final hasUpdate = latestBuild > currentBuild && url.isNotEmpty;
      if (_updateAvailable != hasUpdate) {
        _updateAvailable = hasUpdate;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[APP_UPDATE] Falha ao checar versão mobile: $e');
    } finally {
      _checking = false;
    }
  }

  @override
  Future<void> applyUpdate() async {
    final url = _downloadUrl;
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
