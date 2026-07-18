import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'web_connectivity_hint.dart';

class InternetConnectivityResult {
  final bool hasInternet;
  final String reason;

  const InternetConnectivityResult({
    required this.hasInternet,
    required this.reason,
  });

  const InternetConnectivityResult.online()
      : hasInternet = true,
        reason = 'online';

  const InternetConnectivityResult.offline(this.reason) : hasInternet = false;
}

class InternetConnectivityService {
  InternetConnectivityService._();

  static final InternetConnectivityService instance =
      InternetConnectivityService._();

  static const List<String> _healthUrls = [
    'https://clients3.google.com/generate_204',
    'https://www.gstatic.com/generate_204',
    'https://www.google.com/generate_204',
  ];

  List<String> get _webHealthUrls {
    final base = Uri.base;
    final urls = <String>[];

    final sameOriginPing = base.resolve('/favicon.ico').toString();
    urls.add(sameOriginPing);

    if (base.origin.isNotEmpty) {
      urls.add(base.origin);
    }

    urls.addAll(_healthUrls);
    return urls;
  }

  static const Duration _timeout = Duration(seconds: 4);

  Future<InternetConnectivityResult> hasRealInternet() async {
    if (kIsWeb) {
      return _hasInternetOnWeb();
    }

    for (final url in _healthUrls) {
      final result = await _probeUrl(url);
      if (result.hasInternet) {
        return result;
      }
    }
    return const InternetConnectivityResult.offline(
      'sem resposta de internet em endpoints de verificação',
    );
  }

  Future<InternetConnectivityResult> _hasInternetOnWeb() async {
    final onlineHint = browserOnlineHint();
    if (onlineHint == false) {
      return const InternetConnectivityResult.offline(
        'navigator.onLine=false (web)',
      );
    }

    for (final url in _webHealthUrls) {
      final result = await _probeUrl(url);
      if (result.hasInternet) {
        return const InternetConnectivityResult(
          hasInternet: true,
          reason: 'web_online_confirmed',
        );
      }
    }

    // Em navegadores (especialmente anônimo), probes externos podem falhar por
    // política/CORS mesmo com internet real. Evita falso offline quando o
    // browser indica conexão disponível.
    if (onlineHint == true) {
      return const InternetConnectivityResult(
        hasInternet: true,
        reason: 'web_online_hint_probe_blocked',
      );
    }

    return const InternetConnectivityResult.offline(
      'web sem confirmação de conectividade',
    );
  }

  Future<InternetConnectivityResult> _probeUrl(String url) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(_timeout);
      if (response.statusCode >= 200 && response.statusCode < 500) {
        return const InternetConnectivityResult.online();
      }
      final platform = kIsWeb ? 'web' : 'mobile';
      return InternetConnectivityResult.offline(
        'status inesperado ao checar internet no $platform: ${response.statusCode}',
      );
    } on TimeoutException {
      return InternetConnectivityResult.offline(
        'timeout ao checar internet em $url',
      );
    } catch (e) {
      return InternetConnectivityResult.offline(
        'erro ao checar internet em $url: $e',
      );
    }
  }
}
