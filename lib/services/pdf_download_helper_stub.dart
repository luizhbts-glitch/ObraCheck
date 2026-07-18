import 'dart:typed_data';

void downloadBytes({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) {
  throw UnsupportedError('Download de arquivo no navegador está disponível apenas na web.');
}

void downloadPdfBytes({required Uint8List bytes, required String fileName}) {
  throw UnsupportedError('Download de PDF no navegador está disponível apenas na web.');
}

