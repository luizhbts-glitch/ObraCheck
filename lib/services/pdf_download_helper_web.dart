// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:typed_data';

void downloadBytes({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) {
  final blob = html.Blob(<dynamic>[bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..style.display = 'none';

  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}

void downloadPdfBytes({required Uint8List bytes, required String fileName}) {
  downloadBytes(bytes: bytes, fileName: fileName, mimeType: 'application/pdf');
}

