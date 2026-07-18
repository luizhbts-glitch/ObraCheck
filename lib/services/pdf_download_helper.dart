import 'dart:typed_data';

import 'pdf_download_helper_stub.dart'
    if (dart.library.html) 'pdf_download_helper_web.dart' as impl;

void downloadBytes({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) {
  impl.downloadBytes(bytes: bytes, fileName: fileName, mimeType: mimeType);
}

void downloadPdfBytes({required Uint8List bytes, required String fileName}) {
  impl.downloadPdfBytes(bytes: bytes, fileName: fileName);
}

