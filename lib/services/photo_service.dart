import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../models/inspection_record.dart';
import '../utils/app_log.dart';

class PhotoService {
  PhotoService._();

  static final PhotoService instance = PhotoService._();

  FirebaseStorage get _storage => FirebaseStorage.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  String sanitizeSegment(String value) {
    final normalized = value.trim().toUpperCase().replaceAll(' ', '-');
    return normalized.replaceAll(RegExp(r'[^A-Z0-9\-_]'), '');
  }

  String buildStoragePath({
    required String obraCode,
    required String torre,
    required String apartamento,
    String? fvsCodigo,
    required String fileName,
  }) {
    final obra = sanitizeSegment(obraCode);
    final torreSegment = sanitizeSegment(torre);
    final aptoSegment = sanitizeSegment(apartamento);
    final fvsSegment = sanitizeSegment(fvsCodigo ?? 'SEM-FVS');
    return 'obras/$obra/nc_photos/$torreSegment/$aptoSegment/$fvsSegment/$fileName';
  }

  String? extractStoragePathFromUrl(String photoUrl) {
    try {
      final uri = Uri.parse(photoUrl);
      final oIndex = uri.pathSegments.indexOf('o');
      if (oIndex < 0 || oIndex + 1 >= uri.pathSegments.length) return null;
      return Uri.decodeComponent(uri.pathSegments[oIndex + 1]);
    } catch (_) {
      return null;
    }
  }

  Future<void> downloadPhoto(String url) async {
    if (url.trim().isEmpty) {
      throw StateError('URL da foto está vazia.');
    }
    final uri = Uri.parse(url);
    final launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (!launched) {
      throw StateError('Não foi possível abrir o download da foto.');
    }
  }

  Future<void> deletePhoto(String storagePath) async {
    final ref = _storage.ref().child(storagePath);
    await ref.delete();
  }

  Future<void> removePhotoReferenceFromFirestore({
    required String obraCode,
    required String recordId,
    required int itemIndex,
    required String photoUrl,
  }) async {
    final docRef = _db
        .collection('obras')
        .doc(obraCode)
        .collection('inspections')
        .doc(recordId);
    final doc = await docRef.get();
    final data = doc.data();
    if (data == null) return;

    final itens = ((data['itens'] as List?) ?? const []).map((e) {
      return Map<String, dynamic>.from((e as Map?) ?? const {});
    }).toList();

    for (var i = 0; i < itens.length; i++) {
      final currentIndex = _safeMapInt(
        itens[i]['index'],
        field: 'PhotoService.removePhotoReferenceFromFirestore.itens[index]',
        defaultValue: -1,
      );
      if (currentIndex != itemIndex) continue;

      final photoPaths = ((itens[i]['photoPaths'] as List?) ?? const [])
          .map((e) => e.toString())
          .where((e) => e != photoUrl)
          .toList();
      final photoUrls = ((itens[i]['photoUrls'] as List?) ?? const [])
          .map((e) => e.toString())
          .where((e) => e != photoUrl)
          .toList();
      final photos = ((itens[i]['photos'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((e) => e['photoUrl']?.toString() != photoUrl)
          .toList();

      itens[i]['photoPaths'] = photoPaths;
      itens[i]['photoUrls'] = photoUrls;
      itens[i]['photos'] = photos;
      break;
    }

    await docRef.set({
      'itens': itens,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    }, SetOptions(merge: true));
  }

  int _safeMapInt(
    dynamic value, {
    required String field,
    int defaultValue = 0,
  }) {
    if (value == null) {
      if (AppLog.enableSyncLogs) {
        debugPrint(
          '[SYNC][NULL_INT_FIX] campo=$field valor=null fallback=$defaultValue',
        );
      }
      return defaultValue;
    }
    if (value is int) return value;
    if (value is num) return value.toInt();
    final parsed = int.tryParse(value.toString());
    if (parsed != null) return parsed;
    if (AppLog.enableSyncLogs) {
      debugPrint(
        '[SYNC][NULL_INT_FIX] campo=$field valor_invalido="$value" fallback=$defaultValue',
      );
    }
    return defaultValue;
  }

  String buildFileNameFromUrl(String photoUrl) {
    final storagePath = extractStoragePathFromUrl(photoUrl);
    if (storagePath == null || storagePath.isEmpty) {
      return 'foto_${DateTime.now().millisecondsSinceEpoch}.jpg';
    }
    final parts = storagePath.split('/');
    return parts.isEmpty
        ? 'foto_${DateTime.now().millisecondsSinceEpoch}.jpg'
        : parts.last;
  }

  bool isRemoteUrl(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.startsWith('http://') ||
        normalized.startsWith('https://');
  }

  bool isFileUrl(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.startsWith('file://');
  }

  bool isDataUrl(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.startsWith('data:image/');
  }

  ParsedImageDataUrl? tryParseImageDataUrl(String value) {
    final raw = value.trim();
    if (!isDataUrl(raw)) return null;

    final commaIndex = raw.indexOf(',');
    if (commaIndex <= 0 || commaIndex >= raw.length - 1) return null;

    final header = raw.substring(0, commaIndex).trim();
    final base64Part = raw.substring(commaIndex + 1).trim();
    final match = RegExp(
      r'^data:([^;]+);base64$',
      caseSensitive: false,
    ).firstMatch(header);
    if (match == null) return null;

    final contentType = (match.group(1) ?? 'image/jpeg').trim().toLowerCase();

    try {
      final bytes = base64Decode(base64Part);
      if (bytes.isEmpty) return null;
      return ParsedImageDataUrl(bytes: bytes, contentType: contentType);
    } catch (_) {
      return null;
    }
  }

  String classifyPhotoValue(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return 'empty';
    if (isRemoteUrl(normalized)) return 'remote-url';
    if (isDataUrl(normalized)) return 'data-url';
    if (isFileUrl(normalized)) return 'file-url';
    if (normalized.startsWith('/') || normalized.contains('\\')) {
      return 'local-path';
    }
    return 'unknown';
  }

  bool isLocalOnlyPhoto(InspectionPhotoData photo) {
    return photo.photoUrl.trim().isEmpty && photo.localPath.trim().isNotEmpty;
  }

  bool hasOnlineUrl(InspectionPhotoData photo) {
    return isRemoteUrl(photo.photoUrl);
  }

  bool canRenderLocalPhoto(InspectionPhotoData photo) {
    return !kIsWeb && photo.localPath.trim().isNotEmpty;
  }

  bool canRenderPhotoOnCurrentPlatform(InspectionPhotoData photo) {
    if (kIsWeb) {
      return photo.storagePath.trim().isNotEmpty ||
          photo.photoUrl.trim().isNotEmpty;
    }
    return resolveBestPhotoSource(photo) != null;
  }

  Future<WebResolvedPhotoUrl?> resolveWebPhotoUrl(
    InspectionPhotoData photo, {
    String? debugTrace,
  }) async {
    if (!kIsWeb) return null;

    final trace = (debugTrace ?? '').trim();
    final tracePrefix = trace.isEmpty ? '' : '$trace ';
    final photoUrl = photo.photoUrl.trim();
    final storagePath = photo.storagePath.trim();

    if (photoUrl.isNotEmpty && (isRemoteUrl(photoUrl) || isDataUrl(photoUrl))) {
      debugPrint(
        '[PHOTO][WEB][URL] ${tracePrefix}source=photoUrl url="$photoUrl"',
      );
      return WebResolvedPhotoUrl(source: 'photoUrl', url: photoUrl);
    }

    if (photoUrl.isNotEmpty && !isRemoteUrl(photoUrl) && !isDataUrl(photoUrl)) {
      debugPrint(
        '[PHOTO][WEB][ERROR] ${tracePrefix}photoUrl preenchido porém não remoto/data-url '
        'valueType=${classifyPhotoValue(photoUrl)}',
      );
    }

    if (storagePath.isEmpty) {
      debugPrint(
        '[PHOTO][WEB][ERROR] ${tracePrefix}sem photoUrl remoto e sem storagePath',
      );
      return null;
    }

    try {
      final url = await _storage.ref(storagePath).getDownloadURL();
      debugPrint(
        '[PHOTO][WEB][DOWNLOAD_URL] ${tracePrefix}source=storagePath path="$storagePath" url="$url"',
      );
      return WebResolvedPhotoUrl(source: 'downloadURL', url: url);
    } catch (e) {
      debugPrint(
        '[PHOTO][WEB][ERROR] ${tracePrefix}falha ao obter downloadURL path="$storagePath" '
        'errorType=${e.runtimeType} error=$e',
      );
      return null;
    }
  }

  Future<Uint8List?> resolveWebPhotoBytes(
    InspectionPhotoData photo, {
    int maxBytes = 15 * 1024 * 1024,
    String logContext = '[PHOTO][WEB][BYTES]',
    String? debugTrace,
  }) async {
    if (!kIsWeb) return null;

    final photoUrl = photo.photoUrl.trim();
    final storagePath = photo.storagePath.trim();
    final trace = (debugTrace ?? '').trim();
    final tracePrefix = trace.isEmpty ? '' : '$trace ';
    void emitStorage(String message) =>
        debugPrint('[PHOTO][WEB][STORAGE] $message');
    void emitDownload(String message) =>
        debugPrint('[PHOTO][WEB][DOWNLOAD] $message');
    void emitError(String message) =>
        debugPrint('[PHOTO][WEB][ERROR] $message');

    final user = FirebaseAuth.instance.currentUser;
    final userUid = user?.uid ?? 'none';
    final userEmail = user?.email ?? 'none';
    final userAnonymous = user?.isAnonymous ?? false;
    final authState = user == null ? 'unauthenticated' : 'authenticated';
    final appOptions = Firebase.app().options;
    final appProjectId = appOptions.projectId;
    final appStorageBucket = appOptions.storageBucket ?? 'none';
    final storageInstanceBucket = _storage.bucket;

    debugPrint(
      'WEBPHOTO123[RESOLVE] service=$runtimeType trace="$trace" kIsWeb=$kIsWeb '
      'photoUrl="$photoUrl" storagePath="$storagePath" localPath="${photo.localPath}"',
    );

    emitStorage(
      '${tracePrefix}authState=$authState uid=$userUid email=$userEmail isAnonymous=$userAnonymous '
      'firebase.projectId=$appProjectId firebase.options.storageBucket=$appStorageBucket '
      'firebase.storage.instance.bucket=$storageInstanceBucket '
      'start '
      'photoUrl="$photoUrl"(${classifyPhotoValue(photoUrl)}) '
      'storagePath="$storagePath" '
      'localPath="${photo.localPath}"(${classifyPhotoValue(photo.localPath)}) '
      'pendingSync=${photo.pendingSync} syncError="${photo.syncError ?? ''}"',
    );

    if (photoUrl.isNotEmpty) {
      final parsedDataUrl = tryParseImageDataUrl(photoUrl);
      if (parsedDataUrl != null) {
        emitDownload(
          '${tracePrefix}stage=data-url success=true bytes=${parsedDataUrl.bytes.length}',
        );
        return parsedDataUrl.bytes;
      } else {
        emitDownload(
          '${tracePrefix}stage=data-url success=false reason=not-data-url',
        );
      }

      try {
        emitStorage(
          '${tracePrefix}stage=photoUrl.refFromURL.getData try=true url="$photoUrl"',
        );
        final bytes = await _storage.refFromURL(photoUrl).getData(maxBytes);
        if (bytes == null || bytes.isEmpty) {
          emitError(
            '${tracePrefix}stage=photoUrl.refFromURL.getData success=false reason=empty-bytes url="$photoUrl"',
          );
        } else {
          emitStorage(
            '${tracePrefix}stage=photoUrl.refFromURL.getData success=true bytes=${bytes.length}',
          );
          return bytes;
        }
      } catch (e) {
        final detail = e.toString().toLowerCase();
        final hint =
            detail.contains('unauthorized') || detail.contains('permission')
            ? 'hint=permission-or-auth'
            : detail.contains('object-not-found')
            ? 'hint=path-not-found'
            : detail.contains('invalid-url')
            ? 'hint=invalid-photoUrl'
            : 'hint=generic-storage-error';
        emitError(
          '${tracePrefix}stage=photoUrl.refFromURL.getData success=false errorType=${e.runtimeType} error=$e $hint',
        );
      }

      try {
        emitDownload('${tracePrefix}stage=http.get try=true url="$photoUrl"');

        final response = await http.get(Uri.parse(photoUrl));

        if (response.statusCode == 200) {
          final bytes = response.bodyBytes;

          if (bytes.isEmpty) {
            emitError(
              '${tracePrefix}stage=http.get success=false reason=empty-bytes url="$photoUrl"',
            );
          } else {
            emitDownload(
              '${tracePrefix}stage=http.get success=true bytes=${bytes.length}',
            );
            return bytes;
          }
        } else {
          emitError(
            '${tracePrefix}stage=http.get failed statusCode=${response.statusCode}',
          );
        }
      } catch (e) {
        final detail = e.toString().toLowerCase();
        final hint = detail.contains('403') || detail.contains('unauthorized')
            ? 'hint=http-auth-or-storage-permission'
            : detail.contains('404')
            ? 'hint=http-not-found-or-invalid-token'
            : detail.contains('cors')
            ? 'hint=cors'
            : 'hint=generic-http-download-error';
        emitError(
          '${tracePrefix}stage=http.get success=false errorType=${e.runtimeType} error=$e $hint',
        );
      }
    } else {
      emitDownload('${tracePrefix}stage=photoUrl skipped=true reason=empty');
    }

    if (storagePath.isEmpty) {
      emitStorage('${tracePrefix}stage=storagePath skipped=true reason=empty');
    } else {
      try {
        emitStorage(
          '${tracePrefix}stage=storagePath.getData try=true path="$storagePath"',
        );
        final bytes = await _storage.ref(storagePath).getData(maxBytes);
        if (bytes == null || bytes.isEmpty) {
          emitError(
            '${tracePrefix}stage=storagePath.getData success=false reason=empty-bytes path="$storagePath"',
          );
        } else {
          emitStorage(
            '${tracePrefix}stage=storagePath.getData success=true bytes=${bytes.length}',
          );
          return bytes;
        }
      } catch (e) {
        final detail = e.toString().toLowerCase();
        final hint =
            detail.contains('unauthorized') || detail.contains('permission')
            ? 'hint=permission-or-auth'
            : detail.contains('object-not-found')
            ? 'hint=path-not-found'
            : 'hint=generic-storage-error';
        emitError(
          '${tracePrefix}stage=storagePath.getData success=false errorType=${e.runtimeType} error=$e $hint',
        );
      }

      try {
        emitStorage(
          '${tracePrefix}stage=storagePath.getDownloadURL try=true path="$storagePath"',
        );
        final storageUrl = await _storage.ref(storagePath).getDownloadURL();
        emitStorage(
          '${tracePrefix}stage=storagePath.getDownloadURL success=true url="$storageUrl"',
        );

        try {
          emitDownload(
            '${tracePrefix}stage=http.get try=true url="$storageUrl"',
          );

          final response = await http.get(Uri.parse(storageUrl));

          if (response.statusCode == 200) {
            final bytes = response.bodyBytes;

            if (bytes.isEmpty) {
              emitError(
                '${tracePrefix}stage=http.get success=false reason=empty-bytes url="$storageUrl"',
              );
            } else {
              emitDownload(
                '${tracePrefix}stage=http.get success=true bytes=${bytes.length}',
              );
              return bytes;
            }
          } else {
            emitError(
              '${tracePrefix}stage=http.get failed statusCode=${response.statusCode}',
            );
          }
        } catch (e) {
          emitError(
            '${tracePrefix}stage=http.get errorType=${e.runtimeType} error=$e',
          );
        }
      } catch (e) {
        final detail = e.toString().toLowerCase();
        final hint =
            detail.contains('unauthorized') || detail.contains('permission')
            ? 'hint=permission-or-auth'
            : detail.contains('object-not-found')
            ? 'hint=path-not-found'
            : detail.contains('403') || detail.contains('404')
            ? 'hint=download-url-http-error'
            : 'hint=generic-storage-or-http-error';
        emitError(
          '${tracePrefix}stage=storagePath.getDownloadURL success=false errorType=${e.runtimeType} error=$e $hint',
        );
      }
    }

    emitError(
      '${tracePrefix}final=failure '
      'photoUrlType=${classifyPhotoValue(photo.photoUrl)} '
      'storagePath="${photo.storagePath}" pendingSync=${photo.pendingSync}',
    );

    return null;
  }

  String? resolveBestPhotoSource(InspectionPhotoData photo) {
    if (kDebugMode) {
      debugPrint(
        '[PHOTO][RESOLVE] platform=${kIsWeb ? 'web' : 'mobile'} '
        'photoUrl="${photo.photoUrl}"(${classifyPhotoValue(photo.photoUrl)}) '
        'localPath="${photo.localPath}"(${classifyPhotoValue(photo.localPath)}) '
        'storagePath="${photo.storagePath}" '
        'pendingSync=${photo.pendingSync}',
      );
    }

    if (kIsWeb) {
      final webPhotoUrl = photo.photoUrl.trim();
      if (webPhotoUrl.isNotEmpty) {
        if (kDebugMode) {
          debugPrint(
            '[PHOTO][RESOLVE] selected=photoUrl reason=web-photoUrl-only',
          );
        }
        return webPhotoUrl;
      }
      if (kDebugMode) {
        debugPrint('[PHOTO][RESOLVE] selected=null reason=web-photoUrl-empty');
      }
      return null;
    }

    if (canRenderLocalPhoto(photo)) {
      if (kDebugMode) {
        debugPrint(
          '[PHOTO][RESOLVE] selected=localPath reason=mobile-local-supported',
        );
      }
      return photo.localPath;
    }

    if (hasOnlineUrl(photo)) {
      if (kDebugMode) {
        debugPrint('[PHOTO][RESOLVE] selected=photoUrl reason=remote-url');
      }
      return photo.photoUrl;
    }

    // Compatibilidade com registros legados mobile que persistiam caminho em photoUrl.
    if (photo.photoUrl.trim().isNotEmpty) {
      if (kDebugMode) {
        debugPrint(
          '[PHOTO][RESOLVE] selected=photoUrl reason=legacy-mobile-fallback',
        );
      }
      return photo.photoUrl;
    }

    if (kDebugMode) {
      debugPrint('[PHOTO][RESOLVE] selected=null reason=no-compatible-source');
    }

    return null;
  }

  Future<void> deleteLocalPhotoIfExists(String localPath) async {
    final normalized = localPath.trim();
    if (normalized.isEmpty || kIsWeb) return;

    final file = File(normalized);
    if (await file.exists()) {
      await file.delete();
    }
  }

  String toPrettyJson(Map<String, dynamic> photoData) => jsonEncode(photoData);
}

class ParsedImageDataUrl {
  const ParsedImageDataUrl({required this.bytes, required this.contentType});

  final Uint8List bytes;
  final String contentType;
}

class WebResolvedPhotoUrl {
  const WebResolvedPhotoUrl({required this.source, required this.url});

  final String source;
  final String url;

  WebResolvedPhotoUrl copyWith({String? source, String? url}) {
    return WebResolvedPhotoUrl(
      source: source ?? this.source,
      url: url ?? this.url,
    );
  }
}
