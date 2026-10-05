import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Grava uma faixa de identificação na parte de baixo da imagem (marca
/// d'água legível: texto branco sobre faixa escura) pra que a foto continue
/// identificada fora do app. Usa `dart:ui` — suporta acentos, ao contrário
/// do pacote `image`. Devolve PNG (o `dart:ui` não codifica JPEG); quem chama
/// recomprime pra JPEG quando a plataforma permite.
Future<Uint8List> carimbarFoto(Uint8List bytes, List<String> linhas) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final width = image.width.toDouble();
  final height = image.height.toDouble();

  final textLines = linhas.where((l) => l.trim().isNotEmpty).toList();
  if (textLines.isEmpty) {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    codec.dispose();
    return data!.buffer.asUint8List();
  }

  final padding = (width * 0.02).clamp(8.0, 40.0);
  final fontSize = (width / 46).clamp(11.0, 48.0);
  final maxTextWidth = width - padding * 2;

  final painters = <TextPainter>[];
  for (final line in textLines) {
    final painter = TextPainter(
      text: TextSpan(
        text: line,
        style: TextStyle(
          color: const Color(0xFFFFFFFF),
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          height: 1.15,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: maxTextWidth);
    painters.add(painter);
  }

  final textHeight = painters.fold<double>(0, (t, p) => t + p.height);
  final bandHeight = textHeight + padding * 1.4;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawImage(image, Offset.zero, Paint());
  canvas.drawRect(
    Rect.fromLTWH(0, height - bandHeight, width, bandHeight),
    Paint()..color = const Color(0xCC000000),
  );
  var dy = height - bandHeight + padding * 0.7;
  for (final p in painters) {
    p.paint(canvas, Offset(padding, dy));
    dy += p.height;
  }

  final picture = recorder.endRecording();
  final stamped = await picture.toImage(image.width, image.height);
  final data = await stamped.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  stamped.dispose();
  codec.dispose();
  return data!.buffer.asUint8List();
}
