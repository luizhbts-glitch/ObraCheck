import 'dart:convert';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../models/medicao_campo_record.dart';
import '../utils/foto_carimbo.dart';
import '../utils/medicao_campo_rules.dart';

/// Captura, compressão e identificação das fotos da medição de campo.
///
/// Fluxo: câmera/galeria já limitando o maior lado a 1600 px (JPEG ~80%),
/// grava a faixa de identificação na própria imagem, recomprime pra JPEG
/// (mobile) e salva — arquivo no aparelho (mobile) ou data URL (web, onde
/// não existe arquivo local).
class MedicaoFotoService {
  MedicaoFotoService._();

  static final MedicaoFotoService instance = MedicaoFotoService._();

  static const double maxSide = 1600;
  static const int quality = 80;

  final ImagePicker _picker = ImagePicker();

  /// Retorna `null` se o usuário cancelou. [dataHora] vira a hora da foto.
  Future<MedicaoCampoFoto?> capturar({
    required ImageSource source,
    required MedicaoCampoRecord medicao,
    required MedicaoCampoApto apto,
    required String usuario,
  }) async {
    final picked = await _picker.pickImage(
      source: source,
      preferredCameraDevice: CameraDevice.rear,
      maxWidth: maxSide,
      maxHeight: maxSide,
      imageQuality: quality,
    );
    if (picked == null) return null;

    final agora = DateTime.now();
    final legenda = buildMedicaoFotoLegenda(
      obra: medicao.obra,
      torre: apto.torre,
      apto: apto.label,
      servico: servicoComElementos(medicao.servicoNome, medicao.elementos),
      empreiteiro: medicao.empreiteiroNome,
      dataHora: agora,
      usuario: usuario,
    );

    final original = await picked.readAsBytes();
    var stamped = await carimbarFoto(original, legenda.split('\n'));

    final id = 'mcfoto_${agora.microsecondsSinceEpoch}';

    if (kIsWeb) {
      return MedicaoCampoFoto(
        id: id,
        dataUrl: 'data:image/png;base64,${base64Encode(stamped)}',
        legenda: legenda,
        capturedAt: agora,
        usuario: usuario,
      );
    }

    try {
      final jpeg = await FlutterImageCompress.compressWithList(
        stamped,
        minWidth: maxSide.toInt(),
        minHeight: maxSide.toInt(),
        quality: quality,
        format: CompressFormat.jpeg,
        keepExif: false,
      );
      if (jpeg.isNotEmpty) stamped = Uint8List.fromList(jpeg);
    } catch (e) {
      debugPrint('[MEDICAO_FOTO] Recompressão falhou, mantendo PNG: $e');
    }

    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory(
      '${dir.path}/medicao_fotos/${medicao.id}/${apto.localRef}',
    );
    await folder.create(recursive: true);
    final isJpeg = stamped.length > 2 && stamped[0] == 0xFF && stamped[1] == 0xD8;
    final file = File('${folder.path}/$id.${isJpeg ? 'jpg' : 'png'}');
    await file.writeAsBytes(stamped, flush: true);

    return MedicaoCampoFoto(
      id: id,
      localPath: file.path,
      legenda: legenda,
      capturedAt: agora,
      usuario: usuario,
    );
  }

  /// Bytes da foto pra exibir/colocar no PDF: arquivo local, data URL ou,
  /// por último, a URL remota (só existe depois do sync).
  Future<Uint8List?> lerBytes(MedicaoCampoFoto foto) async {
    if (foto.dataUrl.startsWith('data:')) {
      final comma = foto.dataUrl.indexOf(',');
      if (comma > 0) {
        try {
          return base64Decode(foto.dataUrl.substring(comma + 1));
        } catch (_) {}
      }
    }
    if (!kIsWeb && foto.localPath.isNotEmpty) {
      try {
        final file = File(foto.localPath);
        if (await file.exists()) return await file.readAsBytes();
      } catch (_) {}
    }
    return _lerRemota(foto);
  }

  static const int _maxCache = 60;
  final Map<String, Uint8List> _cacheRemoto = <String, Uint8List>{};

  /// Foto tirada em outro aparelho: só existe no Storage. Cache em memória
  /// pra não baixar de novo a cada rebuild da grade.
  Future<Uint8List?> _lerRemota(MedicaoCampoFoto foto) async {
    final chave = foto.storagePath.isNotEmpty ? foto.storagePath : foto.photoUrl;
    if (chave.isEmpty) return null;
    final cached = _cacheRemoto[chave];
    if (cached != null) return cached;

    Uint8List? bytes;
    try {
      if (foto.storagePath.isNotEmpty) {
        bytes = await FirebaseStorage.instance
            .ref()
            .child(foto.storagePath)
            .getData(15 * 1024 * 1024)
            .timeout(const Duration(seconds: 30));
      }
    } catch (e) {
      debugPrint('[MEDICAO_FOTO] getData falhou (${foto.storagePath}): $e');
    }
    if (bytes == null && foto.photoUrl.startsWith('http')) {
      try {
        final resp = await http
            .get(Uri.parse(foto.photoUrl))
            .timeout(const Duration(seconds: 30));
        if (resp.statusCode == 200) bytes = resp.bodyBytes;
      } catch (e) {
        debugPrint('[MEDICAO_FOTO] download falhou: $e');
      }
    }
    if (bytes == null || bytes.isEmpty) return null;
    if (_cacheRemoto.length >= _maxCache) {
      _cacheRemoto.remove(_cacheRemoto.keys.first);
    }
    _cacheRemoto[chave] = bytes;
    return bytes;
  }

  /// Versão reduzida (~1000 px) só pra dentro do PDF — 64 aptos com várias
  /// fotos de 1600 px passariam de 60 MB. A foto original continua guardada.
  Future<Uint8List?> lerBytesParaPdf(MedicaoCampoFoto foto) async {
    final bytes = await lerBytes(foto);
    if (bytes == null || kIsWeb) return bytes;
    try {
      final menor = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 1000,
        minHeight: 1000,
        quality: 75,
        format: CompressFormat.jpeg,
        keepExif: false,
      );
      return menor.isNotEmpty ? Uint8List.fromList(menor) : bytes;
    } catch (_) {
      return bytes;
    }
  }

  Future<void> apagarArquivo(MedicaoCampoFoto foto) async {
    if (kIsWeb || foto.localPath.isEmpty) return;
    try {
      final file = File(foto.localPath);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
