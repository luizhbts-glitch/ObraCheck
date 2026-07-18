// ignore_for_file: avoid_print

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/company_record.dart';
import '../models/diary_record.dart';
import '../models/inspection_record.dart';
import '../models/service_record.dart';
import 'internet_connectivity_service.dart';
import 'photo_service.dart';
import 'platform_service.dart';
import 'project_context_service.dart';
import '../utils/project_identity.dart';
import '../utils/app_log.dart';

void _syncLog(Object? message) {
  if (!AppLog.enableSyncLogs) return;
  debugPrint(message?.toString() ?? 'null');
}

class SyncCounters {
  final int inspections;
  final int services;
  final int companies;
  final int diaries;
  final int equipments;
  final int movements;
  final int photoPendingBefore;
  final int photoSynced;
  final int photoFailed;
  final int photoPendingAfter;

  const SyncCounters({
    required this.inspections,
    required this.services,
    required this.companies,
    required this.diaries,
    required this.equipments,
    required this.movements,
    required this.photoPendingBefore,
    required this.photoSynced,
    required this.photoFailed,
    required this.photoPendingAfter,
  });
}

class SyncRunStats {
  SyncRunStats() : startedAt = DateTime.now();

  final DateTime startedAt;
  DateTime? endedAt;

  int uploadedInspections = 0;
  int uploadedServices = 0;
  int uploadedCompanies = 0;

  int pulledInspections = 0;
  int pulledServices = 0;
  int pulledCompanies = 0;

  int errors = 0;
  final List<String> errorMessages = [];

  int get durationMs {
    final end = endedAt ?? DateTime.now();
    return end.difference(startedAt).inMilliseconds;
  }

  void markEnded() {
    endedAt = DateTime.now();
  }

  void addError(String message) {
    errors++;
    errorMessages.add(message);
  }
}

class PhotoSyncCounters {
  final int pendingBefore;
  final int synced;
  final int failed;
  final int pendingAfter;

  const PhotoSyncCounters({
    required this.pendingBefore,
    required this.synced,
    required this.failed,
    required this.pendingAfter,
  });

  const PhotoSyncCounters.zero()
    : pendingBefore = 0,
      synced = 0,
      failed = 0,
      pendingAfter = 0;

  PhotoSyncCounters operator +(PhotoSyncCounters other) {
    return PhotoSyncCounters(
      pendingBefore: pendingBefore + other.pendingBefore,
      synced: synced + other.synced,
      failed: failed + other.failed,
      pendingAfter: pendingAfter + other.pendingAfter,
    );
  }
}

class _InspectionPhotoSyncResult {
  final InspectionRecord record;
  final PhotoSyncCounters photoCounters;

  const _InspectionPhotoSyncResult({
    required this.record,
    required this.photoCounters,
  });
}

class SyncAvailability {
  final bool available;
  final String reason;

  const SyncAvailability({required this.available, required this.reason});

  const SyncAvailability.available() : available = true, reason = 'DisponÃ­vel';

  const SyncAvailability.unavailable(this.reason) : available = false;
}

class CloudSyncService {
  CloudSyncService._();
  static final CloudSyncService instance = CloudSyncService._();
  static bool _syncRunning = false;

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  FirebaseStorage get _storage => FirebaseStorage.instance;
  static const Duration _firestoreTimeout = Duration(seconds: 15);

  static const String defaultObraCode = 'ARSEN-SABIA';

  bool isFirestoreDisabledError(Object error) {
    if (error is FirebaseException) {
      final msg = (error.message ?? '').toLowerCase();
      if (msg.contains('cloud firestore api has not been used')) return true;
    }
    final raw = error.toString().toLowerCase();
    return raw.contains('cloud firestore api has not been used');
  }

  Future<T> _runFirestore<T>(Future<T> Function() action) async {
    try {
      return await action().timeout(_firestoreTimeout);
    } catch (e) {
      if (isFirestoreDisabledError(e)) {
        throw StateError('FIRESTORE_API_DISABLED');
      }
      rethrow;
    }
  }

  Future<void> _ensureFirebaseInitialized() async {
    // Firebase Ã© inicializado exclusivamente no main.dart.
    // Mantido como no-op para evitar initializeApp duplicado.
    return;
  }

  bool _hasNewerRemoteDate(DateTime incoming, DateTime local) {
    return incoming.isAfter(local);
  }

  bool _matchesCurrentProject({
    required String recordProjectId,
    required String currentProjectId,
  }) {
    final normalizedRecord = normalizeProjectId(recordProjectId);
    final normalizedCurrent = normalizeProjectId(currentProjectId);
    if (normalizedCurrent.isEmpty) return true;
    if (normalizedRecord.isEmpty) {
      return normalizedCurrent == kLegacyProjectId;
    }
    return normalizedRecord == normalizedCurrent;
  }

  bool _shouldApplyIncomingInspection({
    required InspectionRecord? local,
    required InspectionRecord incoming,
  }) {
    if (local == null) return true;
    if (local.deleted) return false;

    final incomingHasMoreRemotePhotos =
        _countPhotosWithRemoteUrl(incoming) > _countPhotosWithRemoteUrl(local);
    final incomingHasMoreStoragePaths =
        _countPhotosWithStoragePath(incoming) >
        _countPhotosWithStoragePath(local);
    final incomingCompletesLocalPhotos =
        incomingHasMoreRemotePhotos || incomingHasMoreStoragePaths;

    // EstratÃ©gia offline-first:
    // se hÃ¡ alteraÃ§Ã£o local pendente, nÃ£o sobrescrever com pull remoto.
    if (local.pendingSync || local.hasPendingPhotoSync) {
      if (incomingCompletesLocalPhotos) {
        _syncLog(
          '[SYNC][PULL][INSPECTION] Aplicando remoto para completar fotos ausentes localmente '
          'id=${incoming.id} localPendingSync=${local.pendingSync} localPendingPhoto=${local.hasPendingPhotoSync} '
          'localRemote=${_countPhotosWithRemoteUrl(local)} incomingRemote=${_countPhotosWithRemoteUrl(incoming)} '
          'localStorage=${_countPhotosWithStoragePath(local)} incomingStorage=${_countPhotosWithStoragePath(incoming)}',
        );
        return true;
      }
      return false;
    }

    if (incomingCompletesLocalPhotos) {
      return true;
    }

    return _hasNewerRemoteDate(incoming.updatedAt, local.updatedAt);
  }

  int _countPhotosWithRemoteUrl(InspectionRecord record) {
    return record.itens
        .expand((item) => item.photos)
        .where((photo) => PhotoService.instance.isRemoteUrl(photo.photoUrl))
        .length;
  }

  int _countPhotosWithStoragePath(InspectionRecord record) {
    return record.itens
        .expand((item) => item.photos)
        .where((photo) => photo.storagePath.trim().isNotEmpty)
        .length;
  }

  InspectionRecord? _findEquivalentInspectionByLogicalKey({
    required Box<InspectionRecord> inspectionsBox,
    required InspectionRecord incoming,
  }) {
    final incomingKey = incoming.logicalBusinessKey();
    InspectionRecord? best;

    for (final candidate in inspectionsBox.values) {
      if (candidate.deleted) continue;
      if (candidate.id == incoming.id) continue;
      if (candidate.logicalBusinessKey() != incomingKey) continue;
      if (best == null || candidate.updatedAt.isAfter(best.updatedAt)) {
        best = candidate;
      }
    }

    return best;
  }

  @visibleForTesting
  bool shouldApplyIncomingInspectionForTest({
    required InspectionRecord? local,
    required InspectionRecord incoming,
  }) {
    return _shouldApplyIncomingInspection(local: local, incoming: incoming);
  }

  bool _shouldApplyIncomingService({
    required ServiceRecord? local,
    required ServiceRecord incoming,
  }) {
    if (local == null) return true;
    if (local.deleted) return false;
    if (local.pendingSync) return false;
    return _hasNewerRemoteDate(incoming.updatedAt, local.updatedAt);
  }

  @visibleForTesting
  bool shouldApplyIncomingServiceForTest({
    required ServiceRecord? local,
    required ServiceRecord incoming,
  }) {
    return _shouldApplyIncomingService(local: local, incoming: incoming);
  }

  bool _shouldApplyIncomingCompany({
    required CompanyRecord? local,
    required CompanyRecord incoming,
  }) {
    if (local == null) return true;
    if (local.deleted) return false;
    if (local.pendingSync) return false;
    return _hasNewerRemoteDate(incoming.updatedAt, local.updatedAt);
  }

  @visibleForTesting
  bool shouldApplyIncomingCompanyForTest({
    required CompanyRecord? local,
    required CompanyRecord incoming,
  }) {
    return _shouldApplyIncomingCompany(local: local, incoming: incoming);
  }

  bool _shouldApplyIncomingDiary({
    required DiaryRecord? local,
    required DiaryRecord incoming,
  }) {
    if (local == null) return true;
    if (local.deleted) return false;
    if (local.pendingSync) return false;
    return _hasNewerRemoteDate(incoming.updatedAt, local.updatedAt);
  }

  @visibleForTesting
  bool shouldApplyIncomingDiaryForTest({
    required DiaryRecord? local,
    required DiaryRecord incoming,
  }) {
    return _shouldApplyIncomingDiary(local: local, incoming: incoming);
  }

  dynamic _normalizeFirestoreValue(
    dynamic value, {
    required String collection,
    required String docId,
    required String path,
  }) {
    if (value is Timestamp) {
      final date = value.toDate();
      _syncLog(
        '[SYNC][NORMALIZE][$collection][$docId] Timestamp em "$path" => DateTime($date)',
      );
      return date;
    }

    if (value is Map) {
      final out = <String, dynamic>{};
      value.forEach((k, v) {
        final key = k.toString();
        final childPath = path.isEmpty ? key : '$path.$key';
        out[key] = _normalizeFirestoreValue(
          v,
          collection: collection,
          docId: docId,
          path: childPath,
        );
      });
      return out;
    }

    if (value is List) {
      return List<dynamic>.generate(value.length, (index) {
        final childPath = '$path[$index]';
        return _normalizeFirestoreValue(
          value[index],
          collection: collection,
          docId: docId,
          path: childPath,
        );
      });
    }

    return value;
  }

  Map<String, dynamic> _normalizeFirestoreMap(
    Map<String, dynamic> input, {
    required String collection,
    required String docId,
  }) {
    return _normalizeFirestoreValue(
          input,
          collection: collection,
          docId: docId,
          path: '',
        )
        as Map<String, dynamic>;
  }

  Future<String?> getObraCode() async {
    final prefs = Hive.box('prefs');
    final code = prefs.get('obra_code')?.toString().trim();
    if (code == null || code.isEmpty) return null;
    return code;
  }

  Future<SyncAvailability> checkAvailability() async {
    final obraCode = await getObraCode();
    if (obraCode == null || obraCode.trim().isEmpty) {
      return const SyncAvailability.unavailable(
        'Sync indisponível: código da obra ausente',
      );
    }

    final internet = await InternetConnectivityService.instance
        .hasRealInternet();
    if (!internet.hasInternet) {
      final reason = PlatformService.instance.isWeb
          ? '[WEB] modo online indisponível sem conexão'
          : '[SYNC] sem internet, sync ignorada';
      _syncLog('$reason (${internet.reason})');
      return SyncAvailability.unavailable(reason);
    }

    return const SyncAvailability.available();
  }

  Future<PhotoSyncCounters> uploadInspection(InspectionRecord record) async {
    if (record.deleted) {
      _syncLog(
        '[SYNC][INSPECTION] Ignorando upload de relatÃ³rio marcado como deletado: ${record.id}',
      );
      return const PhotoSyncCounters.zero();
    }
    await _ensureFirebaseInitialized();
    final obraCode = await getObraCode();
    if (obraCode == null) return const PhotoSyncCounters.zero();
    final currentProjectId = await ProjectContextService.instance
        .getCurrentProjectId();
    if (!_matchesCurrentProject(
      recordProjectId: record.projectId,
      currentProjectId: currentProjectId,
    )) {
      return const PhotoSyncCounters.zero();
    }

    final syncedResult = await _syncPendingPhotosInInspection(
      record: record,
      obraCode: obraCode,
    );
    final syncedRecord = syncedResult.record;

    final inspectionsBox = Hive.box<InspectionRecord>('inspections');
    await inspectionsBox.put(
      syncedRecord.id,
      syncedRecord.copyWith(pendingSync: syncedRecord.hasPendingPhotoSync),
    );
    _syncLog(
      '[SYNC][INSPECTION] Metadados de foto persistidos localmente antes do push '
      'id=${syncedRecord.id} pendingPhotoSync=${syncedRecord.hasPendingPhotoSync}',
    );

    final payload = syncedRecord.toMap();
    payload['synced'] = !syncedRecord.hasPendingPhotoSync;
    payload['lastSyncedAt'] = Timestamp.fromDate(DateTime.now());
    payload['projectId'] = inferProjectId(
      projectId: syncedRecord.projectId,
      obra: syncedRecord.obra,
    );

    await _runFirestore(
      () => _db
          .collection('obras')
          .doc(obraCode)
          .collection('inspections')
          .doc(record.id)
          .set(payload, SetOptions(merge: true)),
    );

    final latestLocal = inspectionsBox.get(syncedRecord.id);
    final isLocalAhead =
        latestLocal != null && latestLocal.updatedAt.isAfter(record.updatedAt);
    if (isLocalAhead) {
      _syncLog(
        '[SYNC][INSPECTION] AtualizaÃ§Ã£o local mais nova detectada; evitando overwrite apÃ³s upload: ${record.id}',
      );
      return syncedResult.photoCounters;
    }

    await inspectionsBox.put(
      syncedRecord.id,
      syncedRecord.copyWith(pendingSync: syncedRecord.hasPendingPhotoSync),
    );

    final prefs = Hive.box('prefs');
    await prefs.put(
      'inspection_synced_${syncedRecord.id}',
      !syncedRecord.hasPendingPhotoSync,
    );
    await prefs.put(
      'inspection_last_synced_${syncedRecord.id}',
      DateTime.now().toIso8601String(),
    );

    return syncedResult.photoCounters;
  }

  Future<UploadedPhotoData> uploadPhoto({
    required String codigoObra,
    required String torre,
    required String apartamento,
    required String fvsCodigo,
    required String localPath,
  }) async {
    final file = File(localPath);
    final exists = await file.exists();
    _syncLog(
      '[SYNC][PHOTO] Arquivo local ${exists ? 'EXISTE' : 'NÃƒO EXISTE'}: $localPath',
    );
    if (!exists) {
      throw StateError('Arquivo nÃ£o encontrado para upload: $localPath');
    }

    final fileName = localPath.split(RegExp(r'[\\/]')).last;

    final storagePath = PhotoService.instance.buildStoragePath(
      obraCode: codigoObra,
      torre: torre,
      apartamento: apartamento,
      fvsCodigo: fvsCodigo,
      fileName: fileName,
    );

    final ref = _storage.ref().child(storagePath);

    try {
      _syncLog('[SYNC][PHOTO] Upload iniciado. storagePath=$storagePath');
      final uploadTask = await ref.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      _syncLog('[SYNC][PHOTO] Upload concluÃ­do. storagePath=$storagePath');
      return UploadedPhotoData(photoUrl: downloadUrl, storagePath: storagePath);
    } catch (e, s) {
      _syncLog('[SYNC][PHOTO][ERROR] Falha no upload para Storage');
      _syncLog('[SYNC][PHOTO][ERROR] localPath=$localPath');
      _syncLog('[SYNC][PHOTO][ERROR] storagePath=$storagePath');
      _syncLog('[SYNC][PHOTO][ERROR] erro=$e');
      _syncLog(s);
      rethrow;
    }
  }

  Future<UploadedPhotoData> uploadPhotoBytes({
    required String codigoObra,
    required String torre,
    required String apartamento,
    required String fvsCodigo,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    if (bytes.isEmpty) {
      throw StateError('Bytes da foto estÃ£o vazios para upload web.');
    }

    final storagePath = PhotoService.instance.buildStoragePath(
      obraCode: codigoObra,
      torre: torre,
      apartamento: apartamento,
      fvsCodigo: fvsCodigo,
      fileName: fileName,
    );

    final ref = _storage.ref().child(storagePath);

    try {
      _syncLog(
        '[SYNC][PHOTO][WEB] Upload iniciado. storagePath=$storagePath '
        'bytes=${bytes.length} contentType=$contentType',
      );
      final uploadTask = await ref.putData(
        bytes,
        SettableMetadata(contentType: contentType),
      );
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      _syncLog(
        '[SYNC][PHOTO][WEB] Upload concluÃ­do. storagePath=$storagePath',
      );
      return UploadedPhotoData(photoUrl: downloadUrl, storagePath: storagePath);
    } catch (e, s) {
      _syncLog('[SYNC][PHOTO][WEB][ERROR] Falha no upload para Storage');
      _syncLog('[SYNC][PHOTO][WEB][ERROR] storagePath=$storagePath');
      _syncLog(
        '[SYNC][PHOTO][WEB][ERROR] bytes=${bytes.length} contentType=$contentType',
      );
      _syncLog('[SYNC][PHOTO][WEB][ERROR] erro=$e');
      _syncLog(s);
      rethrow;
    }
  }

  Future<_InspectionPhotoSyncResult> _syncPendingPhotosInInspection({
    required InspectionRecord record,
    required String obraCode,
  }) async {
    final syncedItems = <InspectionItemResult>[];
    var pendingBefore = 0;
    var synced = 0;
    var failed = 0;
    var pendingAfter = 0;

    for (final item in record.itens) {
      final currentPhotos = item.photos.isNotEmpty
          ? item.photos
          : item.photoPaths.where((path) => path.trim().isNotEmpty).map((path) {
              final raw = path.trim();
              final isOnline =
                  PhotoService.instance.isRemoteUrl(raw) ||
                  PhotoService.instance.isDataUrl(raw);
              return InspectionPhotoData(
                photoUrl: isOnline ? raw : '',
                storagePath: PhotoService.instance.isRemoteUrl(raw)
                    ? (PhotoService.instance.extractStoragePathFromUrl(raw) ??
                          '')
                    : '',
                localPath: isOnline ? '' : raw,
                pendingSync: !isOnline,
                syncError: null,
              );
            }).toList();

      final syncedPhotos = <InspectionPhotoData>[];
      for (final photo in currentPhotos) {
        final normalizedPhoto = _normalizePhotoBeforeSync(photo);
        final shouldUpload =
            photo.pendingSync ||
            (photo.photoUrl.trim().isEmpty &&
                photo.localPath.trim().isNotEmpty);

        if (shouldUpload) {
          pendingBefore++;
        }

        if (!shouldUpload) {
          final completed = _ensureRemotePhotoMetadata(normalizedPhoto);
          syncedPhotos.add(
            completed.copyWith(pendingSync: false, syncError: null),
          );
          continue;
        }

        _syncLog(
          '[SYNC][PHOTO] Foto pendente encontrada. '
          'record=${record.id} item=${item.index} '
          'localPathType=${PhotoService.instance.classifyPhotoValue(photo.localPath)} '
          'photoUrlType=${PhotoService.instance.classifyPhotoValue(photo.photoUrl)} '
          'storagePath="${photo.storagePath}" web=$kIsWeb',
        );

        try {
          late UploadedPhotoData uploaded;
          if (kIsWeb) {
            final parsedDataUrl = PhotoService.instance.tryParseImageDataUrl(
              normalizedPhoto.photoUrl,
            );

            if (parsedDataUrl == null) {
              throw StateError(
                'Foto pendente na Web sem dataUrl vÃ¡lido para upload. '
                'photoUrlType=${PhotoService.instance.classifyPhotoValue(normalizedPhoto.photoUrl)}',
              );
            }

            final extension = parsedDataUrl.contentType.contains('png')
                ? 'png'
                : parsedDataUrl.contentType.contains('webp')
                ? 'webp'
                : 'jpg';
            final fileName =
                'nc_web_${DateTime.now().millisecondsSinceEpoch}.$extension';

            _syncLog(
              '[SYNC][PHOTO][WEB] Enviando foto pendente. '
              'record=${record.id} item=${item.index} '
              'bytes=${parsedDataUrl.bytes.length} contentType=${parsedDataUrl.contentType}',
            );

            uploaded = await uploadPhotoBytes(
              codigoObra: obraCode,
              torre: record.torre,
              apartamento: record.apto,
              fvsCodigo: record.fvsCodigo,
              bytes: parsedDataUrl.bytes,
              fileName: fileName,
              contentType: parsedDataUrl.contentType,
            );
          } else {
            _syncLog(
              '[SYNC][PHOTO] Enviando foto pendente. '
              'record=${record.id} item=${item.index} localPath=${photo.localPath}',
            );
            uploaded = await uploadPhoto(
              codigoObra: obraCode,
              torre: record.torre,
              apartamento: record.apto,
              fvsCodigo: record.fvsCodigo,
              localPath: photo.localPath,
            );
          }

          _syncLog(
            '[SYNC][PHOTO] Upload bem-sucedido. '
            'record=${record.id} item=${item.index} '
            'photoUrl="${uploaded.photoUrl}" storagePath="${uploaded.storagePath}"',
          );

          final hasRemoteUrl = PhotoService.instance.isRemoteUrl(
            uploaded.photoUrl,
          );
          final hasStoragePath = uploaded.storagePath.trim().isNotEmpty;
          if (!hasRemoteUrl || !hasStoragePath) {
            throw StateError(
              'Upload sem metadados obrigatÃ³rios: '
              'photoUrl="${uploaded.photoUrl}" storagePath="${uploaded.storagePath}"',
            );
          }

          syncedPhotos.add(
            normalizedPhoto.copyWith(
              photoUrl: uploaded.photoUrl,
              storagePath: uploaded.storagePath,
              pendingSync: false,
              syncError: null,
            ),
          );
          synced++;
          _syncLog(
            '[SYNC][PHOTO] PersistÃªncia de metadados concluÃ­da '
            'record=${record.id} item=${item.index} '
            'photoUrlOk=$hasRemoteUrl storagePathOk=$hasStoragePath',
          );
        } catch (e) {
          _syncLog(
            '[SYNC][PHOTO][ERROR] Upload falhou. record=${record.id} item=${item.index} localPath=${photo.localPath} erro=$e',
          );
          failed++;
          pendingAfter++;
          final fallbackPhoto = _ensureRemotePhotoMetadata(normalizedPhoto);
          syncedPhotos.add(
            fallbackPhoto.copyWith(
              photoUrl:
                  PhotoService.instance.isRemoteUrl(fallbackPhoto.photoUrl)
                  ? fallbackPhoto.photoUrl
                  : '',
              storagePath:
                  PhotoService.instance.isRemoteUrl(fallbackPhoto.photoUrl)
                  ? fallbackPhoto.storagePath
                  : '',
              pendingSync: true,
              syncError: e.toString(),
            ),
          );
        }
      }

      syncedItems.add(
        item.copyWith(
          photos: syncedPhotos,
          photoPaths: syncedPhotos
              .map(
                (photo) => photo.photoUrl.trim().isNotEmpty
                    ? photo.photoUrl
                    : photo.localPath,
              )
              .where((value) => value.trim().isNotEmpty)
              .toList(),
        ),
      );
    }

    return _InspectionPhotoSyncResult(
      record: record.copyWith(
        itens: syncedItems,
        updatedAt: synced > 0 ? DateTime.now() : record.updatedAt,
      ),
      photoCounters: PhotoSyncCounters(
        pendingBefore: pendingBefore,
        synced: synced,
        failed: failed,
        pendingAfter: pendingAfter,
      ),
    );
  }

  InspectionPhotoData _normalizePhotoBeforeSync(InspectionPhotoData photo) {
    final trimmedUrl = photo.photoUrl.trim();
    final trimmedStorage = photo.storagePath.trim();
    if (trimmedUrl.isEmpty || !PhotoService.instance.isRemoteUrl(trimmedUrl)) {
      return photo;
    }

    if (trimmedStorage.isNotEmpty) {
      return photo;
    }

    final extracted =
        PhotoService.instance.extractStoragePathFromUrl(trimmedUrl) ?? '';
    if (extracted.trim().isEmpty) {
      return photo;
    }
    return photo.copyWith(storagePath: extracted, syncError: null);
  }

  InspectionPhotoData _ensureRemotePhotoMetadata(InspectionPhotoData photo) {
    if (!PhotoService.instance.isRemoteUrl(photo.photoUrl)) return photo;
    if (photo.storagePath.trim().isNotEmpty) return photo;

    final extracted =
        PhotoService.instance.extractStoragePathFromUrl(photo.photoUrl) ?? '';
    if (extracted.trim().isEmpty) {
      _syncLog(
        '[SYNC][PHOTO][WARN] URL remota sem storagePath extraÃ­vel '
        'photoUrl="${photo.photoUrl}"',
      );
      return photo;
    }

    return photo.copyWith(storagePath: extracted, syncError: null);
  }

  Future<void> _syncPendingInspectionDeletes({
    required String obraCode,
    required Box<InspectionRecord> inspectionsBox,
  }) async {
    final pendingDeletes = inspectionsBox.values
        .where((rec) => rec.deleted && rec.pendingSync)
        .toList();
    _syncLog(
      '[SYNC][DELETE] Deletes pendentes encontrados: ${pendingDeletes.length}',
    );

    for (final rec in pendingDeletes) {
      try {
        _syncLog('[SYNC][DELETE] Removendo remoto: ${rec.id}');
        await _runFirestore(
          () => _db
              .collection('obras')
              .doc(obraCode)
              .collection('inspections')
              .doc(rec.id)
              .delete(),
        );

        await inspectionsBox.delete(rec.id);
        final prefs = Hive.box('prefs');
        await prefs.put('inspection_synced_${rec.id}', true);
        await prefs.put(
          'inspection_last_synced_${rec.id}',
          DateTime.now().toIso8601String(),
        );
        _syncLog(
          '[SYNC][DELETE] RemoÃ§Ã£o concluÃ­da e registro local removido: ${rec.id}',
        );
      } catch (e, s) {
        _syncLog(
          '[SYNC][DELETE][ERROR] Falha ao remover remoto: ${rec.id} erro=$e',
        );
        _syncLog(s);
      }
    }
  }

  Future<void> uploadService(ServiceRecord record) async {
    final availability = await checkAvailability();
    if (!availability.available) return;
    if (record.deleted) {
      _syncLog(
        '[SYNC][SERVICE] Ignorando upload de serviÃ§o deletado: ${record.id}',
      );
      return;
    }
    await _ensureFirebaseInitialized();
    final obraCode = await getObraCode();
    if (obraCode == null) return;
    final currentProjectId = await ProjectContextService.instance
        .getCurrentProjectId();
    if (!_matchesCurrentProject(
      recordProjectId: record.projectId,
      currentProjectId: currentProjectId,
    )) {
      return;
    }
    final payload = record.toMap();
    payload['projectId'] = inferProjectId(
      projectId: record.projectId,
      obra: record.obra,
    );

    await _runFirestore(
      () => _db
          .collection('obras')
          .doc(obraCode)
          .collection('services')
          .doc(record.id)
          .set(payload, SetOptions(merge: true)),
    );

    final servicesBox = Hive.box<ServiceRecord>('services');
    final local = servicesBox.get(record.id);
    if (local != null && !local.deleted) {
      await servicesBox.put(
        local.id,
        local.copyWith(pendingSync: false, updatedAt: DateTime.now()),
      );
    }
  }

  Future<void> uploadCompany(CompanyRecord record) async {
    final availability = await checkAvailability();
    if (!availability.available) return;
    if (record.deleted) {
      _syncLog(
        '[SYNC][COMPANY] Ignorando upload de empresa deletada: ${record.id}',
      );
      return;
    }
    await _ensureFirebaseInitialized();
    final obraCode = await getObraCode();
    if (obraCode == null) return;
    final currentProjectId = await ProjectContextService.instance
        .getCurrentProjectId();
    if (!_matchesCurrentProject(
      recordProjectId: record.projectId,
      currentProjectId: currentProjectId,
    )) {
      return;
    }
    final payload = record.toMap();
    payload['projectId'] = inferProjectId(projectId: record.projectId);

    await _runFirestore(
      () => _db
          .collection('obras')
          .doc(obraCode)
          .collection('companies')
          .doc(record.id)
          .set(payload, SetOptions(merge: true)),
    );

    final companiesBox = Hive.box<CompanyRecord>('companies');
    final local = companiesBox.get(record.id);
    if (local != null && !local.deleted) {
      await companiesBox.put(
        local.id,
        local.copyWith(pendingSync: false, updatedAt: DateTime.now()),
      );
    }
  }

  Future<void> uploadDiary(DiaryRecord record) async {
    final availability = await checkAvailability();
    if (!availability.available) return;
    if (record.deleted) {
      _syncLog(
        '[SYNC][DIARY] Ignorando upload de diÃ¡rio deletado: ${record.id}',
      );
      return;
    }
    await _ensureFirebaseInitialized();
    final obraCode = await getObraCode();
    if (obraCode == null) return;
    final currentProjectId = await ProjectContextService.instance
        .getCurrentProjectId();
    if (!_matchesCurrentProject(
      recordProjectId: record.projectId,
      currentProjectId: currentProjectId,
    )) {
      return;
    }

    final payload = record.toMap();
    payload['projectId'] = inferProjectId(
      projectId: record.projectId,
      obra: record.obra,
    );

    await _runFirestore(
      () => _db
          .collection('obras')
          .doc(obraCode)
          .collection('diaries')
          .doc(record.id)
          .set(payload, SetOptions(merge: true)),
    );

    final diariesBox = Hive.box<DiaryRecord>('diaries');
    final local = diariesBox.get(record.id);
    if (local != null && !local.deleted) {
      await diariesBox.put(
        local.id,
        local.copyWith(pendingSync: false, updatedAt: DateTime.now()),
      );
    }
  }

  Future<void> uploadEquipment(Map<String, dynamic> equipment) async {
    final availability = await checkAvailability();
    if (!availability.available) return;
    if (equipment['deleted'] == true) {
      final id = equipment['id']?.toString() ?? '';
      _syncLog(
        '[SYNC][EQUIPMENT] Ignorando upload de equipamento deletado: $id',
      );
      return;
    }
    await _ensureFirebaseInitialized();
    final obraCode = await getObraCode();
    if (obraCode == null) return;
    final currentProjectId = await ProjectContextService.instance
        .getCurrentProjectId();
    final equipmentProjectId = inferProjectId(
      projectId: equipment['projectId']?.toString(),
      obra: equipment['obra']?.toString(),
    );
    if (!_matchesCurrentProject(
      recordProjectId: equipmentProjectId,
      currentProjectId: currentProjectId,
    )) {
      return;
    }

    final id = equipment['id']?.toString();
    if (id == null || id.isEmpty) return;
    await _runFirestore(
      () => _db
          .collection('obras')
          .doc(obraCode)
          .collection('equipments')
          .doc(id)
          .set({
            ...equipment,
            'projectId': equipmentProjectId,
            'pendingSync': false,
            'updatedAt': Timestamp.fromDate(DateTime.now()),
          }, SetOptions(merge: true)),
    );

    final equipmentsBox = Hive.box('equipments');
    final local = equipmentsBox.get(id);
    if (local is Map) {
      final updated = Map<String, dynamic>.from(local);
      updated['pendingSync'] = false;
      updated['updatedAt'] = DateTime.now();
      await equipmentsBox.put(id, updated);
    }
  }

  Future<void> uploadMovement(Map<String, dynamic> movement) async {
    final availability = await checkAvailability();
    if (!availability.available) return;
    if (movement['deleted'] == true) {
      final id = movement['id']?.toString() ?? '';
      _syncLog('[SYNC][MOVEMENT] Ignorando upload de movimento deletado: $id');
      return;
    }
    await _ensureFirebaseInitialized();
    final obraCode = await getObraCode();
    if (obraCode == null) return;
    final currentProjectId = await ProjectContextService.instance
        .getCurrentProjectId();
    final movementProjectId = inferProjectId(
      projectId: movement['projectId']?.toString(),
      obra: movement['obra']?.toString(),
    );
    if (!_matchesCurrentProject(
      recordProjectId: movementProjectId,
      currentProjectId: currentProjectId,
    )) {
      return;
    }

    final id = movement['id']?.toString();
    if (id == null || id.isEmpty) return;
    final payload = Map<String, dynamic>.from(movement);
    if (payload['createdAt'] is DateTime) {
      payload['createdAt'] = Timestamp.fromDate(
        payload['createdAt'] as DateTime,
      );
    }
    if (payload['updatedAt'] is DateTime) {
      payload['updatedAt'] = Timestamp.fromDate(
        payload['updatedAt'] as DateTime,
      );
    }
    payload['projectId'] = movementProjectId;
    payload['pendingSync'] = false;
    await _runFirestore(
      () => _db
          .collection('obras')
          .doc(obraCode)
          .collection('movements')
          .doc(id)
          .set(payload, SetOptions(merge: true)),
    );

    final movementsBox = Hive.box('equipment_movements');
    final local = movementsBox.get(id);
    if (local is Map) {
      final updated = Map<String, dynamic>.from(local);
      updated['pendingSync'] = false;
      updated['updatedAt'] = DateTime.now();
      await movementsBox.put(id, updated);
    }
  }

  Future<void> _syncPendingServiceDeletes({
    required String obraCode,
    required Box<ServiceRecord> servicesBox,
    required String currentProjectId,
  }) async {
    final pendingDeletes = servicesBox.values
        .where(
          (rec) =>
              rec.deleted &&
              rec.pendingSync &&
              _matchesCurrentProject(
                recordProjectId: rec.projectId,
                currentProjectId: currentProjectId,
              ),
        )
        .toList();
    _syncLog(
      '[SYNC][DELETE][SERVICE] Deletes pendentes encontrados: ${pendingDeletes.length}',
    );
    for (final rec in pendingDeletes) {
      try {
        _syncLog('[SYNC][DELETE][SERVICE] Removendo remoto: ${rec.id}');
        await _runFirestore(
          () => _db
              .collection('obras')
              .doc(obraCode)
              .collection('services')
              .doc(rec.id)
              .delete(),
        );
        await servicesBox.delete(rec.id);
        _syncLog(
          '[SYNC][DELETE][SERVICE] RemoÃ§Ã£o remota concluÃ­da: ${rec.id}',
        );
      } catch (e, s) {
        _syncLog(
          '[SYNC][DELETE][SERVICE][ERROR] Falha ao remover remoto: ${rec.id} erro=$e',
        );
        _syncLog(s);
      }
    }
  }

  Future<void> _syncPendingCompanyDeletes({
    required String obraCode,
    required Box<CompanyRecord> companiesBox,
    required String currentProjectId,
  }) async {
    final pendingDeletes = companiesBox.values
        .where(
          (rec) =>
              rec.deleted &&
              rec.pendingSync &&
              _matchesCurrentProject(
                recordProjectId: rec.projectId,
                currentProjectId: currentProjectId,
              ),
        )
        .toList();
    _syncLog(
      '[SYNC][DELETE][COMPANY] Deletes pendentes encontrados: ${pendingDeletes.length}',
    );
    for (final rec in pendingDeletes) {
      try {
        _syncLog('[SYNC][DELETE][COMPANY] Removendo remoto: ${rec.id}');
        await _runFirestore(
          () => _db
              .collection('obras')
              .doc(obraCode)
              .collection('companies')
              .doc(rec.id)
              .delete(),
        );
        await companiesBox.delete(rec.id);
        _syncLog(
          '[SYNC][DELETE][COMPANY] RemoÃ§Ã£o remota concluÃ­da: ${rec.id}',
        );
      } catch (e, s) {
        _syncLog(
          '[SYNC][DELETE][COMPANY][ERROR] Falha ao remover remoto: ${rec.id} erro=$e',
        );
        _syncLog(s);
      }
    }
  }

  Future<void> _syncPendingDiaryDeletes({
    required String obraCode,
    required Box<DiaryRecord> diariesBox,
    required String currentProjectId,
  }) async {
    final pendingDeletes = diariesBox.values
        .where(
          (rec) =>
              rec.deleted &&
              rec.pendingSync &&
              _matchesCurrentProject(
                recordProjectId: rec.projectId,
                currentProjectId: currentProjectId,
              ),
        )
        .toList();
    _syncLog(
      '[SYNC][DELETE][DIARY] Deletes pendentes encontrados: ${pendingDeletes.length}',
    );
    for (final rec in pendingDeletes) {
      try {
        _syncLog('[SYNC][DELETE][DIARY] Removendo remoto: ${rec.id}');
        await _runFirestore(
          () => _db
              .collection('obras')
              .doc(obraCode)
              .collection('diaries')
              .doc(rec.id)
              .delete(),
        );
        await diariesBox.delete(rec.id);
        _syncLog(
          '[SYNC][DELETE][DIARY] RemoÃ§Ã£o remota concluÃ­da: ${rec.id}',
        );
      } catch (e, s) {
        _syncLog(
          '[SYNC][DELETE][DIARY][ERROR] Falha ao remover remoto: ${rec.id} erro=$e',
        );
        _syncLog(s);
      }
    }
  }

  Future<void> _syncPendingEquipmentDeletes({
    required String obraCode,
    required Box equipmentsBox,
    required String currentProjectId,
  }) async {
    final pendingDeletes = <Map<String, dynamic>>[];
    for (final raw in equipmentsBox.values) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final projectId = inferProjectId(
        projectId: item['projectId']?.toString(),
        obra: item['obra']?.toString(),
      );
      if (item['deleted'] == true &&
          item['pendingSync'] == true &&
          _matchesCurrentProject(
            recordProjectId: projectId,
            currentProjectId: currentProjectId,
          )) {
        pendingDeletes.add(item);
      }
    }

    _syncLog(
      '[SYNC][DELETE][EQUIPMENT] Deletes pendentes encontrados: ${pendingDeletes.length}',
    );
    for (final rec in pendingDeletes) {
      final id = rec['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      try {
        _syncLog('[SYNC][DELETE][EQUIPMENT] Removendo remoto: $id');
        await _runFirestore(
          () => _db
              .collection('obras')
              .doc(obraCode)
              .collection('equipments')
              .doc(id)
              .delete(),
        );
        await equipmentsBox.delete(id);
        _syncLog('[SYNC][DELETE][EQUIPMENT] RemoÃ§Ã£o remota concluÃ­da: $id');
      } catch (e, s) {
        _syncLog(
          '[SYNC][DELETE][EQUIPMENT][ERROR] Falha ao remover remoto: $id erro=$e',
        );
        _syncLog(s);
      }
    }
  }

  Future<void> _syncPendingMovementDeletes({
    required String obraCode,
    required Box movementsBox,
    required String currentProjectId,
  }) async {
    final pendingDeletes = <Map<String, dynamic>>[];
    for (final raw in movementsBox.values) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final projectId = inferProjectId(
        projectId: item['projectId']?.toString(),
        obra: item['obra']?.toString(),
      );
      if (item['deleted'] == true &&
          item['pendingSync'] == true &&
          _matchesCurrentProject(
            recordProjectId: projectId,
            currentProjectId: currentProjectId,
          )) {
        pendingDeletes.add(item);
      }
    }

    _syncLog(
      '[SYNC][DELETE][MOVEMENT] Deletes pendentes encontrados: ${pendingDeletes.length}',
    );
    for (final rec in pendingDeletes) {
      final id = rec['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      try {
        _syncLog('[SYNC][DELETE][MOVEMENT] Removendo remoto: $id');
        await _runFirestore(
          () => _db
              .collection('obras')
              .doc(obraCode)
              .collection('movements')
              .doc(id)
              .delete(),
        );
        await movementsBox.delete(id);
        _syncLog('[SYNC][DELETE][MOVEMENT] RemoÃ§Ã£o remota concluÃ­da: $id');
      } catch (e, s) {
        _syncLog(
          '[SYNC][DELETE][MOVEMENT][ERROR] Falha ao remover remoto: $id erro=$e',
        );
        _syncLog(s);
      }
    }
  }

  Future<SyncCounters> syncNow() async {
    if (_syncRunning) {
      _syncLog('[SYNC] syncNow ignorado: jÃ¡ existe execuÃ§Ã£o em andamento');
      return const SyncCounters(
        inspections: 0,
        services: 0,
        companies: 0,
        diaries: 0,
        equipments: 0,
        movements: 0,
        photoPendingBefore: 0,
        photoSynced: 0,
        photoFailed: 0,
        photoPendingAfter: 0,
      );
    }
    _syncRunning = true;

    try {
      final stats = SyncRunStats();
      final availability = await checkAvailability();
      if (!availability.available) {
        _syncLog('[SYNC] syncNow abortado: ${availability.reason}');
        stats.markEnded();
        return const SyncCounters(
          inspections: 0,
          services: 0,
          companies: 0,
          diaries: 0,
          equipments: 0,
          movements: 0,
          photoPendingBefore: 0,
          photoSynced: 0,
          photoFailed: 0,
          photoPendingAfter: 0,
        );
      }
      await _ensureFirebaseInitialized();
      final obraCode = await getObraCode();
      if (obraCode == null) {
        stats.markEnded();
        return const SyncCounters(
          inspections: 0,
          services: 0,
          companies: 0,
          diaries: 0,
          equipments: 0,
          movements: 0,
          photoPendingBefore: 0,
          photoSynced: 0,
          photoFailed: 0,
          photoPendingAfter: 0,
        );
      }

      final inspectionsBox = Hive.box<InspectionRecord>('inspections');
      final servicesBox = Hive.box<ServiceRecord>('services');
      final companiesBox = Hive.box<CompanyRecord>('companies');
      final diariesBox = Hive.box<DiaryRecord>('diaries');
      final equipmentsBox = Hive.box('equipments');
      final movementsBox = Hive.box('equipment_movements');

      final prefs = Hive.box('prefs');
      final currentProjectId = await ProjectContextService.instance
          .getCurrentProjectId();
      var photoCounters = const PhotoSyncCounters.zero();

      await _syncPendingInspectionDeletes(
        obraCode: obraCode,
        inspectionsBox: inspectionsBox,
      );
      await _syncPendingEquipmentDeletes(
        obraCode: obraCode,
        equipmentsBox: equipmentsBox,
        currentProjectId: currentProjectId,
      );
      await _syncPendingMovementDeletes(
        obraCode: obraCode,
        movementsBox: movementsBox,
        currentProjectId: currentProjectId,
      );
      await _syncPendingServiceDeletes(
        obraCode: obraCode,
        servicesBox: servicesBox,
        currentProjectId: currentProjectId,
      );
      await _syncPendingCompanyDeletes(
        obraCode: obraCode,
        companiesBox: companiesBox,
        currentProjectId: currentProjectId,
      );
      await _syncPendingDiaryDeletes(
        obraCode: obraCode,
        diariesBox: diariesBox,
        currentProjectId: currentProjectId,
      );

      final inspectionCandidates =
          inspectionsBox.values.where((rec) => !rec.deleted).toList()
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      final processedLogicalKeys = <String>{};

      for (final rec in inspectionCandidates) {
        if (rec.deleted) continue;
        if (!_matchesCurrentProject(
          recordProjectId: rec.projectId,
          currentProjectId: currentProjectId,
        )) {
          continue;
        }

        final logicalKey = rec.logicalBusinessKey();
        if (processedLogicalKeys.contains(logicalKey)) {
          _syncLog(
            '[DUPLICATE_PREVENTED][SYNC_PUSH] Ignorando envio duplicado '
            'id=${rec.id} key=$logicalKey',
          );
          continue;
        }

        final alreadySynced = prefs.get('inspection_synced_${rec.id}') == true;
        final shouldSync =
            rec.pendingSync || rec.hasPendingPhotoSync || !alreadySynced;
        if (!shouldSync) continue;
        try {
          final counters = await uploadInspection(rec);
          photoCounters = photoCounters + counters;
          stats.uploadedInspections++;
          processedLogicalKeys.add(logicalKey);
        } catch (e, s) {
          _syncLog('[SYNC][INSPECTION][ERROR] Falha ao enviar ${rec.id}: $e');
          _syncLog(s);
          stats.addError('[uploadInspection:${rec.id}] $e');
        }
      }
      for (final rec in servicesBox.values) {
        if (rec.deleted) continue;
        if (!_matchesCurrentProject(
          recordProjectId: rec.projectId,
          currentProjectId: currentProjectId,
        )) {
          continue;
        }
        if (!rec.pendingSync) continue;
        try {
          await uploadService(rec);
          stats.uploadedServices++;
        } catch (e, s) {
          _syncLog('[SYNC][SERVICE][ERROR] Falha ao enviar ${rec.id}: $e');
          _syncLog(s);
          stats.addError('[uploadService:${rec.id}] $e');
        }
      }
      for (final rec in companiesBox.values) {
        if (rec.deleted) continue;
        if (!_matchesCurrentProject(
          recordProjectId: rec.projectId,
          currentProjectId: currentProjectId,
        )) {
          continue;
        }
        if (!rec.pendingSync) continue;
        try {
          await uploadCompany(rec);
          stats.uploadedCompanies++;
        } catch (e, s) {
          _syncLog('[SYNC][COMPANY][ERROR] Falha ao enviar ${rec.id}: $e');
          _syncLog(s);
          stats.addError('[uploadCompany:${rec.id}] $e');
        }
      }
      for (final rec in diariesBox.values) {
        if (rec.deleted) continue;
        if (!_matchesCurrentProject(
          recordProjectId: rec.projectId,
          currentProjectId: currentProjectId,
        )) {
          continue;
        }
        if (!rec.pendingSync) continue;
        try {
          await uploadDiary(rec);
        } catch (e, s) {
          _syncLog('[SYNC][DIARY][ERROR] Falha ao enviar ${rec.id}: $e');
          _syncLog(s);
        }
      }
      for (final key in equipmentsBox.keys) {
        final data = equipmentsBox.get(key);
        if (data is Map) {
          final equipment = Map<String, dynamic>.from(data);
          final equipmentProjectId = inferProjectId(
            projectId: equipment['projectId']?.toString(),
            obra: equipment['obra']?.toString(),
          );
          if (!_matchesCurrentProject(
            recordProjectId: equipmentProjectId,
            currentProjectId: currentProjectId,
          )) {
            continue;
          }
          if (equipment['deleted'] == true) continue;
          if (equipment['pendingSync'] != true) continue;
          equipment['id'] = (equipment['id'] ?? key).toString();
          try {
            await uploadEquipment(equipment);
          } catch (e, s) {
            _syncLog(
              '[SYNC][EQUIPMENT][ERROR] Falha ao enviar ${equipment['id']}: $e',
            );
            _syncLog(s);
          }
        }
      }
      for (final key in movementsBox.keys) {
        final data = movementsBox.get(key);
        if (data is Map) {
          final movement = Map<String, dynamic>.from(data);
          final movementProjectId = inferProjectId(
            projectId: movement['projectId']?.toString(),
            obra: movement['obra']?.toString(),
          );
          if (!_matchesCurrentProject(
            recordProjectId: movementProjectId,
            currentProjectId: currentProjectId,
          )) {
            continue;
          }
          if (movement['deleted'] == true) continue;
          if (movement['pendingSync'] != true) continue;
          movement['id'] = (movement['id'] ?? key).toString();
          try {
            await uploadMovement(movement);
          } catch (e, s) {
            _syncLog(
              '[SYNC][MOVEMENT][ERROR] Falha ao enviar ${movement['id']}: $e',
            );
            _syncLog(s);
          }
        }
      }

      var pulledInspections = 0;
      var pulledServices = 0;
      var pulledCompanies = 0;
      var pulledDiaries = 0;
      var pulledEquipments = 0;
      var pulledMovements = 0;

      final inspectionsSnap = await _runFirestore(
        () => _db
            .collection('obras')
            .doc(obraCode)
            .collection('inspections')
            .get(),
      );
      for (final doc in inspectionsSnap.docs) {
        final normalized = _normalizeFirestoreMap(
          Map<String, dynamic>.from(doc.data()),
          collection: 'inspections',
          docId: doc.id,
        );
        final incoming = InspectionRecord.fromMap(normalized);
        if (!_matchesCurrentProject(
          recordProjectId: incoming.projectId,
          currentProjectId: currentProjectId,
        )) {
          continue;
        }
        final local = inspectionsBox.get(incoming.id);
        final equivalent = local == null
            ? _findEquivalentInspectionByLogicalKey(
                inspectionsBox: inspectionsBox,
                incoming: incoming,
              )
            : null;
        final localForDecision = local ?? equivalent;

        if (equivalent != null) {
          _syncLog(
            '[DUPLICATE_PREVENTED][SYNC_PULL] '
            'incomingId=${incoming.id} reuseLocalId=${equivalent.id} key=${incoming.logicalBusinessKey()}',
          );
        }

        if (localForDecision?.deleted == true) {
          _syncLog(
            '[SYNC][PULL] Ignorando doc remoto ${incoming.id} pois existe tombstone local pendente.',
          );
          continue;
        }
        if (incoming.deleted) {
          if (local != null) {
            await inspectionsBox.delete(incoming.id);
          }
          continue;
        }

        if (_shouldApplyIncomingInspection(
          local: localForDecision,
          incoming: incoming,
        )) {
          if (local != null) {
            await inspectionsBox.put(incoming.id, incoming);
          } else if (equivalent != null) {
            await inspectionsBox.put(
              equivalent.id,
              incoming.copyWith(id: equivalent.id),
            );
          } else {
            await inspectionsBox.put(incoming.id, incoming);
          }
          stats.pulledInspections++;
          pulledInspections++;
        }
      }

      final servicesSnap = await _runFirestore(
        () =>
            _db.collection('obras').doc(obraCode).collection('services').get(),
      );
      for (final doc in servicesSnap.docs) {
        final normalized = _normalizeFirestoreMap(
          Map<String, dynamic>.from(doc.data()),
          collection: 'services',
          docId: doc.id,
        );
        final incoming = ServiceRecord.fromMap(normalized);
        if (!_matchesCurrentProject(
          recordProjectId: incoming.projectId,
          currentProjectId: currentProjectId,
        )) {
          continue;
        }
        final local = servicesBox.get(incoming.id);
        if (local?.deleted == true) {
          _syncLog(
            '[SYNC][PULL][SERVICE] Ignorando remoto ${incoming.id} por tombstone local.',
          );
          continue;
        }
        if (incoming.deleted) {
          await servicesBox.delete(incoming.id);
          continue;
        }
        if (_shouldApplyIncomingService(local: local, incoming: incoming)) {
          await servicesBox.put(incoming.id, incoming);
          stats.pulledServices++;
          pulledServices++;
        }
      }

      final companiesSnap = await _runFirestore(
        () =>
            _db.collection('obras').doc(obraCode).collection('companies').get(),
      );
      for (final doc in companiesSnap.docs) {
        final normalized = _normalizeFirestoreMap(
          Map<String, dynamic>.from(doc.data()),
          collection: 'companies',
          docId: doc.id,
        );
        final incoming = CompanyRecord.fromMap(normalized);
        if (!_matchesCurrentProject(
          recordProjectId: incoming.projectId,
          currentProjectId: currentProjectId,
        )) {
          continue;
        }
        final local = companiesBox.get(incoming.id);
        if (local?.deleted == true) {
          _syncLog(
            '[SYNC][PULL][COMPANY] Ignorando remoto ${incoming.id} por tombstone local.',
          );
          continue;
        }
        if (incoming.deleted) {
          await companiesBox.delete(incoming.id);
          continue;
        }
        if (_shouldApplyIncomingCompany(local: local, incoming: incoming)) {
          await companiesBox.put(incoming.id, incoming);
          stats.pulledCompanies++;
          pulledCompanies++;
        }
      }

      final diariesSnap = await _runFirestore(
        () => _db.collection('obras').doc(obraCode).collection('diaries').get(),
      );
      for (final doc in diariesSnap.docs) {
        final normalized = _normalizeFirestoreMap(
          Map<String, dynamic>.from(doc.data()),
          collection: 'diaries',
          docId: doc.id,
        );
        final incoming = DiaryRecord.fromMap(normalized);
        if (!_matchesCurrentProject(
          recordProjectId: incoming.projectId,
          currentProjectId: currentProjectId,
        )) {
          continue;
        }
        final local = diariesBox.get(incoming.id);
        if (local?.deleted == true) {
          _syncLog(
            '[SYNC][PULL][DIARY] Ignorando remoto ${incoming.id} por tombstone local.',
          );
          continue;
        }
        if (incoming.deleted) {
          await diariesBox.delete(incoming.id);
          continue;
        }
        if (_shouldApplyIncomingDiary(local: local, incoming: incoming)) {
          await diariesBox.put(
            incoming.id,
            incoming.copyWith(pendingSync: false),
          );
          pulledDiaries++;
        }
      }

      final equipmentsSnap = await _runFirestore(
        () => _db
            .collection('obras')
            .doc(obraCode)
            .collection('equipments')
            .get(),
      );
      for (final doc in equipmentsSnap.docs) {
        final incoming = _normalizeFirestoreMap(
          Map<String, dynamic>.from(doc.data()),
          collection: 'equipments',
          docId: doc.id,
        );
        final localRaw = equipmentsBox.get(doc.id);
        final local = localRaw is Map
            ? Map<String, dynamic>.from(localRaw)
            : null;
        if (local != null && local['deleted'] == true) {
          _syncLog(
            '[SYNC][PULL][EQUIPMENT] Ignorando remoto ${doc.id} por tombstone local.',
          );
          continue;
        }
        if (local != null && local['pendingSync'] == true) {
          _syncLog(
            '[SYNC][PULL][EQUIPMENT] Mantendo local pendente (offline-first): ${doc.id}',
          );
          continue;
        }
        if (incoming['deleted'] == true) {
          await equipmentsBox.delete(doc.id);
          continue;
        }
        final incomingProjectId = inferProjectId(
          projectId: incoming['projectId']?.toString(),
          obra: incoming['obra']?.toString(),
        );
        if (!_matchesCurrentProject(
          recordProjectId: incomingProjectId,
          currentProjectId: currentProjectId,
        )) {
          continue;
        }
        incoming['id'] = (incoming['id'] ?? doc.id).toString();
        incoming['projectId'] = incomingProjectId;
        incoming['pendingSync'] = false;
        await equipmentsBox.put(doc.id, incoming);
        pulledEquipments++;
      }

      final movementsSnap = await _runFirestore(
        () =>
            _db.collection('obras').doc(obraCode).collection('movements').get(),
      );
      for (final doc in movementsSnap.docs) {
        final data = _normalizeFirestoreMap(
          Map<String, dynamic>.from(doc.data()),
          collection: 'movements',
          docId: doc.id,
        );
        final localRaw = movementsBox.get(doc.id);
        final local = localRaw is Map
            ? Map<String, dynamic>.from(localRaw)
            : null;
        if (local != null && local['deleted'] == true) {
          _syncLog(
            '[SYNC][PULL][MOVEMENT] Ignorando remoto ${doc.id} por tombstone local.',
          );
          continue;
        }
        if (local != null && local['pendingSync'] == true) {
          _syncLog(
            '[SYNC][PULL][MOVEMENT] Mantendo local pendente (offline-first): ${doc.id}',
          );
          continue;
        }
        if (data['deleted'] == true) {
          await movementsBox.delete(doc.id);
          continue;
        }
        final incomingProjectId = inferProjectId(
          projectId: data['projectId']?.toString(),
          obra: data['obra']?.toString(),
        );
        if (!_matchesCurrentProject(
          recordProjectId: incomingProjectId,
          currentProjectId: currentProjectId,
        )) {
          continue;
        }
        data['id'] = (data['id'] ?? doc.id).toString();
        data['projectId'] = incomingProjectId;
        data['pendingSync'] = false;
        await movementsBox.put(doc.id, data);
        pulledMovements++;
      }

      stats.markEnded();
      _syncLog('[SYNC][SUMMARY]');
      _syncLog('durationMs=${stats.durationMs}');
      _syncLog('uploadedInspections=${stats.uploadedInspections}');
      _syncLog('pulledInspections=${stats.pulledInspections}');
      _syncLog('errors=${stats.errors}');

      return SyncCounters(
        inspections: pulledInspections,
        services: pulledServices,
        companies: pulledCompanies,
        diaries: pulledDiaries,
        equipments: pulledEquipments,
        movements: pulledMovements,
        photoPendingBefore: photoCounters.pendingBefore,
        photoSynced: photoCounters.synced,
        photoFailed: photoCounters.failed,
        photoPendingAfter: photoCounters.pendingAfter,
      );
    } finally {
      _syncRunning = false;
    }
  }
}

class UploadedPhotoData {
  final String photoUrl;
  final String storagePath;

  const UploadedPhotoData({required this.photoUrl, required this.storagePath});
}
