import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obra_check/models/medicao_campo_record.dart';
import 'package:obra_check/services/pdf_report_service.dart';
import 'package:obra_check/utils/foto_carimbo.dart';

final Uint8List _png1x1 = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

MedicaoCampoApto _apto(String label, {int fotos = 0, String obs = ''}) {
  return MedicaoCampoApto(
    torre: 'Paris',
    localRef: 'APTO_$label',
    label: label,
    andar: int.parse(label.substring(0, label.length - 2)),
    status: MedicaoStatus.conferido,
    observacao: obs,
    fotos: List.generate(
      fotos,
      (i) => MedicaoCampoFoto(
        id: '$label-$i',
        legenda: 'Obra: Arsen | Torre: Paris | Apto: $label\nServiço: Piso | Empreiteiro: Silva\n05/10/2026 09:07 | Usuário: Luiz',
        capturedAt: DateTime(2026, 10, 5, 9, 7),
        usuario: 'Luiz',
      ),
    ),
  );
}

MedicaoCampoRecord _record(List<MedicaoCampoApto> aptos) {
  return MedicaoCampoRecord(
    id: 'm1',
    projectId: 'p',
    obra: 'Arsen Sabiá',
    servicoCodigo: '5.4',
    servicoNome: 'Execução de piso cerâmico',
    empreiteiroId: 'e1',
    empreiteiroNome: 'Pisador - Silva',
    periodo: 'Medição 03',
    responsavelNome: 'Luiz',
    aptos: aptos,
    createdAt: DateTime(2026, 10, 5),
    updatedAt: DateTime(2026, 10, 5),
    ano: 2026,
    mes: 9,
  );
}

int _pageCount(Uint8List bytes) {
  final text = latin1.decode(bytes, allowInvalid: true);
  return RegExp(r'/Type\s*/Page(?![s\w])').allMatches(text).length;
}

void main() {
  final service = PdfReportService();

  test('gera um PDF válido só com os apartamentos da medição', () async {
    final record = _record([_apto('1101', fotos: 2, obs: 'ok'), _apto('1102')]);
    final bytes = await service.gerarMedicaoCampoBytes(
      record: record,
      fotosPorApto: {
        record.aptos[0].chave: [_png1x1, _png1x1],
        record.aptos[1].chave: const [],
      },
      geradoEm: DateTime(2026, 10, 5, 10, 0),
    );
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    // capa+resumo, página das fotos do 1101 (o 1102 não tem foto e não ganha página)
    expect(_pageCount(bytes), 2);
  });

  test('cada apartamento com foto ganha a própria página', () async {
    final record = _record([
      _apto('1101', fotos: 1),
      _apto('1102', fotos: 1),
      _apto('1103', fotos: 1),
    ]);
    final bytes = await service.gerarMedicaoCampoBytes(
      record: record,
      fotosPorApto: {
        for (final a in record.aptos) a.chave: [_png1x1],
      },
      geradoEm: DateTime(2026, 10, 5),
    );
    expect(_pageCount(bytes), 4);
  });

  test('foto indisponível no aparelho não derruba o PDF', () async {
    final record = _record([_apto('1101', fotos: 3)]);
    final bytes = await service.gerarMedicaoCampoBytes(
      record: record,
      fotosPorApto: {
        record.aptos.single.chave: [_png1x1, null, _png1x1],
      },
      geradoEm: DateTime(2026, 10, 5),
    );
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('medição sem fotos gera só a capa', () async {
    final record = _record([_apto('1101'), _apto('1102'), _apto('1103')]);
    final bytes = await service.gerarMedicaoCampoBytes(
      record: record,
      fotosPorApto: const {},
      geradoEm: DateTime(2026, 10, 5),
    );
    expect(_pageCount(bytes), 1);
  });

  testWidgets('carimbarFoto devolve PNG do mesmo tamanho com a faixa gravada', (tester) async {
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 400, 300),
        Paint()..color = const Color(0xFF3366CC),
      );
      final base = await recorder.endRecording().toImage(400, 300);
      final data = await base.toByteData(format: ui.ImageByteFormat.png);
      final original = data!.buffer.asUint8List();

      final out = await carimbarFoto(original, [
        'Obra: Arsen Sabiá | Torre: Paris | Apto: 1101',
        'Serviço: Piso | Empreiteiro: Silva',
        '05/10/2026 09:07 | Usuário: Luiz',
      ]);

      expect(out.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
      final codec = await ui.instantiateImageCodec(out);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 400);
      expect(frame.image.height, 300);

      // a faixa escura cobre a base: o pixel do canto inferior esquerdo não é mais azul
      final px = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final offset = ((300 - 3) * 400 + 3) * 4;
      final r = px!.getUint8(offset);
      final g = px.getUint8(offset + 1);
      final b = px.getUint8(offset + 2);
      expect(b < 0x99 && g < 0x66 && r < 0x44, isTrue, reason: 'rgb=$r,$g,$b');
    });
  });
}
