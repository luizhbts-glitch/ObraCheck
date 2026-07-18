import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import 'photo_service.dart';

class StorageMigrationService {
  StorageMigrationService._();

  static final StorageMigrationService instance = StorageMigrationService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<StorageMigrationReport> migrateLegacyNcPhotos({
    String obraCode = 'ARSEN-SABIA',
    bool dryRun = false,
  }) async {
    final report = StorageMigrationReport(obraCode: obraCode);

    final inspections = await _db
        .collection('obras')
        .doc(obraCode)
        .collection('inspections')
        .get();

    for (final doc in inspections.docs) {
      final data = Map<String, dynamic>.from(doc.data());
      final itens = ((data['itens'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      var docChanged = false;
      final updatedItens = <Map<String, dynamic>>[];

      for (final item in itens) {
        final itemIndex = (item['index'] ?? -1) is int
            ? item['index'] as int
            : int.tryParse('${item['index']}') ?? -1;

        final currentPhotos = _extractPhotoEntries(item);
        if (currentPhotos.isEmpty) {
          updatedItens.add(item);
          continue;
        }

        final nextPhotos = <_PhotoEntry>[];
        var itemChanged = false;

        for (final photo in currentPhotos) {
          final sourcePath = _normalizeStoragePath(photo.storagePath, photo.photoUrl);
          if (sourcePath == null) {
            nextPhotos.add(photo);
            continue;
          }

          final legacy = _parseLegacyPath(sourcePath);
          if (legacy == null) {
            nextPhotos.add(photo);
            continue;
          }

          final fileName = sourcePath.split('/').last;
          final destPath = PhotoService.instance.buildStoragePath(
            obraCode: obraCode,
            torre: legacy.torre,
            apartamento: legacy.apto,
            fvsCodigo: legacy.fvs,
            fileName: fileName,
          );

          String destUrl = photo.photoUrl;
          String finalPath = sourcePath;
          String status = 'unchanged';
          String? error;

          if (destPath != sourcePath) {
            try {
              if (!dryRun) {
                destUrl = await _copyIfNeeded(
                  sourcePath: sourcePath,
                  destPath: destPath,
                );
                finalPath = destPath;
              } else {
                status = 'planned';
                finalPath = destPath;
              }
              itemChanged = true;
              docChanged = true;
              status = dryRun ? 'planned' : 'copied';
            } catch (e) {
              error = e.toString();
              status = 'error';
              report.errors++;
            }
          }

          report.entries.add(
            MigrationEntry(
              inspectionId: doc.id,
              itemIndex: itemIndex,
              oldPath: sourcePath,
              newPath: finalPath,
              oldUrl: photo.photoUrl,
              newUrl: destUrl,
              status: status,
              error: error,
            ),
          );

          nextPhotos.add(
            _PhotoEntry(
              photoUrl: destUrl,
              storagePath: finalPath,
            ),
          );
        }

        if (itemChanged && !dryRun) {
          item['photos'] = nextPhotos
              .map((e) => {'photoUrl': e.photoUrl, 'storagePath': e.storagePath})
              .toList();
          item['photoUrls'] = nextPhotos.map((e) => e.photoUrl).toList();
          item['photoPaths'] = nextPhotos.map((e) => e.photoUrl).toList();
        }

        updatedItens.add(item);
      }

      if (docChanged && !dryRun) {
        await doc.reference.set({
          'itens': updatedItens,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        }, SetOptions(merge: true));
        report.updatedRecords++;
      }
    }

    report.migratedFiles = report.entries.where((e) => e.status == 'copied').length;
    report.plannedFiles = report.entries.where((e) => e.status == 'planned').length;
    return report;
  }

  Future<String> _copyIfNeeded({
    required String sourcePath,
    required String destPath,
  }) async {
    final sourceRef = _storage.ref().child(sourcePath);
    final destRef = _storage.ref().child(destPath);

    try {
      final existing = await destRef.getDownloadURL();
      return existing;
    } catch (_) {
      // destino ainda não existe
    }

    final metadata = await sourceRef.getMetadata();
    final bytes = await sourceRef.getData(50 * 1024 * 1024);
    if (bytes == null) {
      throw StateError('Falha ao ler bytes de $sourcePath');
    }

    await destRef.putData(
      bytes,
      SettableMetadata(contentType: metadata.contentType),
    );
    return await destRef.getDownloadURL();
  }

  _LegacyPathData? _parseLegacyPath(String storagePath) {
    final marker = '/nc_photos/';
    final idx = storagePath.indexOf(marker);
    if (idx < 0) return null;

    final after = storagePath.substring(idx + marker.length);
    final firstSegment = after.split('/').first;
    final decoded = Uri.decodeComponent(firstSegment);
    if (!decoded.startsWith('draft:')) return null;

    final parts = decoded.split(':');
    if (parts.length < 6) return null;

    // Legado (sem projectId): draft:<obra>:<torre>:<andar>:<local>:<fvs>
    // Atual (escopado): draft:<projectId>:<obra>:<torre>:<andar>:<local>:<fvs>...
    final hasScopedProjectPrefix = parts.length >= 7;
    final offset = hasScopedProjectPrefix ? 1 : 0;

    final torre = parts[2 + offset].trim();
    final localRef = parts[4 + offset].trim();
    final fvs = parts[5 + offset].trim();

    final apto = localRef.toUpperCase().startsWith('APTO_')
        ? localRef.substring(5)
        : localRef;

    return _LegacyPathData(
      torre: torre,
      apto: apto,
      fvs: fvs,
    );
  }

  String? _normalizeStoragePath(String? storagePath, String photoUrl) {
    final fromPath = storagePath?.trim();
    if (fromPath != null && fromPath.isNotEmpty) {
      return Uri.decodeComponent(fromPath);
    }
    final extracted = PhotoService.instance.extractStoragePathFromUrl(photoUrl);
    if (extracted == null || extracted.trim().isEmpty) return null;
    return extracted;
  }

  List<_PhotoEntry> _extractPhotoEntries(Map<String, dynamic> item) {
    final explicit = ((item['photos'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .map(
          (e) => _PhotoEntry(
            photoUrl: (e['photoUrl'] ?? '').toString(),
            storagePath: (e['storagePath'] ?? '').toString(),
          ),
        )
        .where((e) => e.photoUrl.trim().isNotEmpty)
        .toList();
    if (explicit.isNotEmpty) return explicit;

    final urls = ((item['photoUrls'] as List?) ??
            (item['photoPaths'] as List?) ??
            const [])
        .map((e) => e.toString())
        .where((e) => e.trim().isNotEmpty)
        .toList();

    return urls.map((url) => _PhotoEntry(photoUrl: url, storagePath: '')).toList();
  }
}

class StorageMigrationReport {
  StorageMigrationReport({required this.obraCode});

  final String obraCode;
  int updatedRecords = 0;
  int migratedFiles = 0;
  int plannedFiles = 0;
  int errors = 0;
  final List<MigrationEntry> entries = [];

  void debugPrintSummary() {
    debugPrint(
      '[StorageMigrationReport] obra=$obraCode updatedRecords=$updatedRecords migrated=$migratedFiles planned=$plannedFiles errors=$errors',
    );
  }
}

class MigrationEntry {
  const MigrationEntry({
    required this.inspectionId,
    required this.itemIndex,
    required this.oldPath,
    required this.newPath,
    required this.oldUrl,
    required this.newUrl,
    required this.status,
    this.error,
  });

  final String inspectionId;
  final int itemIndex;
  final String oldPath;
  final String newPath;
  final String oldUrl;
  final String newUrl;
  final String status;
  final String? error;

  Map<String, dynamic> toMap() {
    return {
      'inspectionId': inspectionId,
      'itemIndex': itemIndex,
      'oldPath': oldPath,
      'newPath': newPath,
      'oldUrl': oldUrl,
      'newUrl': newUrl,
      'status': status,
      'error': error,
    };
  }
}

class _LegacyPathData {
  const _LegacyPathData({
    required this.torre,
    required this.apto,
    required this.fvs,
  });

  final String torre;
  final String apto;
  final String fvs;
}

class _PhotoEntry {
  const _PhotoEntry({
    required this.photoUrl,
    required this.storagePath,
  });

  final String photoUrl;
  final String storagePath;
}
