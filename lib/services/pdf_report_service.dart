// ignore_for_file: unused_element, curly_braces_in_flow_control_structures

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/inspection_record.dart';
import '../models/medicao_campo_record.dart';
import '../utils/medicao_campo_rules.dart';
import '../utils/report_inspection_rules.dart';
import 'matrix_report_builder.dart';
import 'medicao_foto_service.dart';
import 'pdf_download_helper.dart';

class PdfExportResult {
  const PdfExportResult({
    required this.fileName,
    this.filePath,
    this.downloadedInBrowser = false,
  });

  final String fileName;
  final String? filePath;
  final bool downloadedInBrowser;
}

class PdfReportService {
  Future<Uint8List> gerarPdfBytes(InspectionRecord record) async {
    final pdf = pw.Document();
    final payload = await _payloadFromRecord(record);
    _addTechnicalReportPages(pdf, payload);
    return pdf.save();
  }

  Future<PdfExportResult> exportarPdf(InspectionRecord record) async {
    final bytes = await gerarPdfBytes(record);
    final fileName = _buildWebFriendlyFileName(record);

    if (kIsWeb) {
      downloadPdfBytes(bytes: bytes, fileName: fileName);
      return PdfExportResult(fileName: fileName, downloadedInBrowser: true);
    }

    final file = await _savePdfToDocuments(bytes: bytes, fileName: fileName);
    try {
      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Relatório de inspeção ${record.fvsCodigo}');
    } catch (_) {
      // Mantém o arquivo salvo para abertura manual pela UI caso necessário.
    }

    return PdfExportResult(fileName: fileName, filePath: file.path);
  }

  Future<File> generate(InspectionRecord record) async {
    final bytes = await gerarPdfBytes(record);
    final fileName = _buildFileName(record);
    return _savePdfToDocuments(bytes: bytes, fileName: fileName);
  }

  String _savedByName(InspectionRecord record) {
    final byName = (record.actionByName ?? '').trim();
    if (byName.isNotEmpty) return byName;
    final byUid = (record.actionByUid ?? '').trim();
    if (byUid.isNotEmpty)
      return 'UID ${byUid.length > 8 ? byUid.substring(0, 8) : byUid}';
    return '—';
  }

  void _addTechnicalReportPages(pw.Document pdf, _FvsPdfPayload payload) {
    final matrixData = _buildMatrixReportData(payload);
    final locationChunks = _chunkList<String>(matrixData.locations, 8);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 32),
        header: (ctx) {
          if (ctx.pageNumber != 1) return pw.SizedBox.shrink();
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader(payload, folhaText: 'Folha ${ctx.pageNumber}/—'),
              pw.SizedBox(height: 8),
              _buildMetaGrid(payload),
              pw.SizedBox(height: 10),
              _buildLegend(),
              pw.SizedBox(height: 8),
              _buildSectionTitle('ITENS VERIFICADOS'),
            ],
          );
        },
        footer: (ctx) => _buildFooter(payload),
        build: (ctx) {
          final content = <pw.Widget>[];

          if (locationChunks.isEmpty || matrixData.rows.isEmpty) {
            content.add(_buildEmptyMatrixBody());
          } else {
            for (var i = 0; i < locationChunks.length; i++) {
              final rowChunks = _chunkList(matrixData.rows, 24);
              for (var j = 0; j < rowChunks.length; j++) {
                content.add(
                  _buildMatrixBlockTable(
                    rows: rowChunks[j],
                    locations: locationChunks[i],
                  ),
                );
                if (j < rowChunks.length - 1 || i < locationChunks.length - 1) {
                  content.add(pw.SizedBox(height: 10));
                }
              }
            }
          }

          if (payload.photos.isNotEmpty) {
            content.add(pw.SizedBox(height: 12));
            content.add(_buildSectionTitle('REGISTRO FOTOGRÁFICO'));
            content.add(_buildPhotosSection(payload.photos));
          }

          if (payload.openedNc ||
              payload.items.any((i) => _normalizeStatus(i.status) == 'nok')) {
            content.add(pw.SizedBox(height: 12));
            content.add(_buildNcSection(payload));
          }

          content.add(pw.SizedBox(height: 12));
          content.add(_buildGeneralNotesSection(payload.generalNotes));
          content.add(pw.SizedBox(height: 20));
          content.add(_buildSignaturesBlock());

          return content;
        },
      ),
    );
  }

  Future<_FvsPdfPayload> _payloadFromRecord(InspectionRecord record) async {
    final location = _displayLocation(record);
    final photos = await _collectRenderablePhotos(record);
    final generalNotes = record.itens
        .where((i) => i.obs.trim().isNotEmpty)
        .map((i) => '${i.index + 1}. ${i.obs.trim()}')
        .join('\n');
    return _FvsPdfPayload(
      obraNome: _safe(record.obra),
      tower: _safe(record.torre),
      location: _safe(location),
      fvsCode: _safe(record.fvsCodigo),
      fvsName: _safe(record.fvsNome),
      operationalSheetLabel: _safe(record.operationalSheetLabel ?? ''),
      inspectionDate: reportInspectionLastActionAt(record),
      inspectorName: _savedByName(record),
      statusLabel: reportInspectionStatusLabel(record),
      items: List<InspectionItemResult>.from(record.itens),
      photos: photos,
      openedNc: record.hasOpenNc,
      generalNotes: generalNotes,
    );
  }

  Future<List<_PdfPhotoEntry>> _collectRenderablePhotos(
    InspectionRecord record,
  ) async {
    final out = <_PdfPhotoEntry>[];
    for (final item in record.itens) {
      for (final photo in item.photos) {
        final bytes = await _readPhotoBytes(photo);
        if (bytes == null) continue;
        out.add(
          _PdfPhotoEntry(bytes: bytes, caption: _truncate(item.descricao, 20)),
        );
      }
    }
    return out;
  }

  Future<Uint8List?> _readPhotoBytes(InspectionPhotoData photo) async {
    final remote = photo.photoUrl.trim();
    if (remote.startsWith('http://') || remote.startsWith('https://')) {
      try {
        final client = HttpClient();
        final req = await client.getUrl(Uri.parse(remote));
        final resp = await req.close();
        if (resp.statusCode != 200) return null;
        final data = await resp.fold<List<int>>(<int>[], (acc, chunk) {
          acc.addAll(chunk);
          return acc;
        });
        return Uint8List.fromList(data);
      } catch (_) {
        return null;
      }
    }

    final local = photo.localPath.trim();
    if (local.isNotEmpty) {
      try {
        final file = File(local);
        if (await file.exists()) {
          return await file.readAsBytes();
        }
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  // Exporta PDF no estilo consolidado para uma única inspeção (web + mobile).
  Future<PdfExportResult> exportarPdfConsolidadoIndividual(
    InspectionRecord record,
  ) async {
    final pdf = await _buildConsolidadoPdfDoc(
      projectId: record.projectId,
      obraFixa: record.obra,
      torre: record.torre,
      fvsCodigo: record.fvsCodigo,
      fvsNomeOverride: record.fvsNome,
      operationalSheetId: record.operationalSheetId,
      operationalSheetLabel: record.operationalSheetLabel,
      sourceRecords: [record],
      includeDrafts: true,
    );
    final bytes = await pdf.save();
    final fileName = _buildWebFriendlyFileName(record);

    if (kIsWeb) {
      downloadPdfBytes(bytes: bytes, fileName: fileName);
      return PdfExportResult(fileName: fileName, downloadedInBrowser: true);
    }

    final file = await _savePdfToDocuments(bytes: bytes, fileName: fileName);
    try {
      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Relatório de inspeção ${record.fvsCodigo}');
    } catch (_) {}
    return PdfExportResult(fileName: fileName, filePath: file.path);
  }

  Future<PdfExportResult> exportarRelatorioConsolidado({
    required String projectId,
    required String obraFixa,
    required String torre,
    required String fvsCodigo,
    String? fvsNomeOverride,
    String? operationalSheetId,
    String? operationalSheetLabel,
    required List<InspectionRecord> sourceRecords,
    required bool includeDrafts,
  }) async {
    final pdf = await _buildConsolidadoPdfDoc(
      projectId: projectId,
      obraFixa: obraFixa,
      torre: torre,
      fvsCodigo: fvsCodigo,
      fvsNomeOverride: fvsNomeOverride,
      operationalSheetId: operationalSheetId,
      operationalSheetLabel: operationalSheetLabel,
      sourceRecords: sourceRecords,
      includeDrafts: includeDrafts,
    );
    final bytes = await pdf.save();
    final dt = DateTime.now();
    final stamp =
        '${dt.year.toString().padLeft(4, '0')}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}_${dt.hour.toString().padLeft(2, '0')}${dt.minute.toString().padLeft(2, '0')}';
    final sheetSuffix = (operationalSheetLabel ?? '').trim();
    final fileName = _sanitize(
      'Relatorio_Consolidado_${obraFixa}_${torre}_$fvsCodigo${sheetSuffix.isEmpty ? '' : '_$sheetSuffix'}_$stamp.pdf',
    );

    if (kIsWeb) {
      downloadPdfBytes(bytes: bytes, fileName: fileName);
      return PdfExportResult(fileName: fileName, downloadedInBrowser: true);
    }

    final file = await _savePdfToDocuments(bytes: bytes, fileName: fileName);
    return PdfExportResult(fileName: fileName, filePath: file.path);
  }

  /// Relatório individual em lote — pedido do usuário em 2026-09-30: escolhe
  /// torre + FVS, seleciona várias unidades (ex.: 1101, 1102, 1103) e sai um
  /// PDF só, com uma página por unidade. Página enxuta ("comprovação de
  /// medição"): contagem geral (conforme/corrigido/NC aberta), detalha só os
  /// itens que precisam de atenção (X/XO) e anexa as fotos da unidade — não
  /// lista item por item que está OK, já que o objetivo é comprovar o que
  /// está sendo pago, não repetir o checklist inteiro.
  Future<PdfExportResult> exportarRelatorioIndividualEmLote(
    List<InspectionRecord> records,
  ) async {
    final pdf = pw.Document();
    for (final record in records) {
      final payload = await _payloadFromRecord(record);
      _addResumoMedicaoPage(pdf, payload);
    }
    final bytes = await pdf.save();

    final dt = DateTime.now();
    final stamp =
        '${dt.year.toString().padLeft(4, '0')}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}_${dt.hour.toString().padLeft(2, '0')}${dt.minute.toString().padLeft(2, '0')}';
    final first = records.first;
    final fileName = _sanitize(
      'Relatorio_Individual_${first.obra}_${first.torre}_${first.fvsCodigo}_$stamp.pdf',
    );

    if (kIsWeb) {
      downloadPdfBytes(bytes: bytes, fileName: fileName);
      return PdfExportResult(fileName: fileName, downloadedInBrowser: true);
    }

    final file = await _savePdfToDocuments(bytes: bytes, fileName: fileName);
    try {
      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Relatório individual de inspeção — ${records.length} unidade(s)');
    } catch (_) {}
    return PdfExportResult(fileName: fileName, filePath: file.path);
  }

  /// Medição de campo — PDF de comprovação dos apartamentos pagos numa
  /// medição: capa com resumo, tabela por apartamento e uma seção por
  /// apartamento com as fotos (2 por linha) e a legenda de identificação.
  /// Só entram os apartamentos da própria medição.
  Future<PdfExportResult> exportarMedicaoCampo(MedicaoCampoRecord record) async {
    final fotos = <String, List<Uint8List?>>{};
    for (final apto in record.aptos) {
      final lista = <Uint8List?>[];
      for (final foto in apto.fotos) {
        lista.add(await MedicaoFotoService.instance.lerBytesParaPdf(foto));
      }
      fotos[apto.chave] = lista;
    }
    final bytes = await gerarMedicaoCampoBytes(
      record: record,
      fotosPorApto: fotos,
      geradoEm: DateTime.now(),
    );

    final dt = DateTime.now();
    final stamp =
        '${dt.year.toString().padLeft(4, '0')}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}_${dt.hour.toString().padLeft(2, '0')}${dt.minute.toString().padLeft(2, '0')}';
    final fileName = _sanitize(
      'Medicao_${record.obra}_${record.servicoNome}_${record.empreiteiroNome}_$stamp.pdf',
    );

    if (kIsWeb) {
      downloadPdfBytes(bytes: bytes, fileName: fileName);
      return PdfExportResult(fileName: fileName, downloadedInBrowser: true);
    }

    final file = await _savePdfToDocuments(bytes: bytes, fileName: fileName);
    try {
      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Medição ${record.servicoNome} - ${record.empreiteiroNome}');
    } catch (_) {}
    return PdfExportResult(fileName: fileName, filePath: file.path);
  }

  /// Monta o PDF a partir dos dados já carregados (sem tocar em Hive nem em
  /// arquivos) — separado do `exportarMedicaoCampo` pra poder ser testado.
  /// [fotosPorApto] usa `MedicaoCampoApto.chave` e a mesma ordem de `fotos`.
  Future<Uint8List> gerarMedicaoCampoBytes({
    required MedicaoCampoRecord record,
    required Map<String, List<Uint8List?>> fotosPorApto,
    required DateTime geradoEm,
  }) async {
    final pdf = pw.Document();
    final aptos = List<MedicaoCampoApto>.from(record.aptos)
      ..sort(compararAptosMedicao);
    final resumo = resumirMedicao(aptos);
    final responsavel = record.responsavelNome.trim().isEmpty
        ? '-'
        : record.responsavelNome.trim();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 32),
        header: (ctx) => _medicaoHeader(record),
        footer: (ctx) => _medicaoFooter(ctx, record),
        build: (ctx) {
          final content = <pw.Widget>[
            pw.SizedBox(height: 10),
            _medicaoCapa(record, resumo, responsavel, geradoEm),
            pw.SizedBox(height: 12),
            _buildSectionTitle('RESUMO POR APARTAMENTO'),
            _medicaoTabelaResumo(aptos),
          ];

          for (final apto in aptos) {
            final fotos = fotosPorApto[apto.chave] ?? const <Uint8List?>[];
            final temFotos = apto.fotos.isNotEmpty;
            if (temFotos) {
              content.add(pw.NewPage());
            } else {
              content.add(pw.SizedBox(height: 14));
            }
            content.add(_medicaoAptoTitulo(apto));
            if (apto.observacao.trim().isNotEmpty) {
              content.add(pw.SizedBox(height: 4));
              content.add(
                pw.Text(
                  'Observação: ${apto.observacao.trim()}',
                  style: pw.TextStyle(
                    font: pw.Font.helvetica(),
                    fontSize: 9,
                    color: _hex(0xFF1A1A1A),
                  ),
                ),
              );
            }
            if (!temFotos) {
              content.add(pw.SizedBox(height: 4));
              content.add(
                pw.Text(
                  'Sem fotos registradas.',
                  style: pw.TextStyle(
                    font: pw.Font.helvetica(),
                    fontSize: 8.5,
                    color: _hex(0xFF777777),
                  ),
                ),
              );
              continue;
            }
            content.add(pw.SizedBox(height: 8));
            for (var i = 0; i < apto.fotos.length; i += 2) {
              content.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 10),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: _medicaoFotoCelula(
                          apto.fotos[i],
                          i < fotos.length ? fotos[i] : null,
                        ),
                      ),
                      pw.SizedBox(width: 10),
                      pw.Expanded(
                        child: i + 1 < apto.fotos.length
                            ? _medicaoFotoCelula(
                                apto.fotos[i + 1],
                                i + 1 < fotos.length ? fotos[i + 1] : null,
                              )
                            : pw.SizedBox(),
                      ),
                    ],
                  ),
                ),
              );
            }
          }
          return content;
        },
      ),
    );
    return pdf.save();
  }

  pw.Widget _medicaoHeader(MedicaoCampoRecord record) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Medição de Serviço',
              style: pw.TextStyle(
                font: pw.Font.helveticaBold(),
                fontSize: 13,
                color: _hex(0xFF1A1A1A),
              ),
            ),
            pw.Text(
              record.obra,
              style: pw.TextStyle(
                font: pw.Font.helvetica(),
                fontSize: 8,
                color: _hex(0xFF777777),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 3),
        pw.Container(height: 2, color: _hex(0xFF1A1A1A)),
      ],
    );
  }

  pw.Widget _medicaoFooter(pw.Context ctx, MedicaoCampoRecord record) {
    pw.Widget linha(String label) => pw.Expanded(
      child: pw.Column(
        children: [
          pw.Container(height: 0.7, color: _hex(0xFF1A1A1A)),
          pw.SizedBox(height: 2),
          pw.Text(
            label,
            style: pw.TextStyle(
              font: pw.Font.helvetica(),
              fontSize: 7,
              color: _hex(0xFF555555),
            ),
          ),
        ],
      ),
    );

    return pw.Column(
      children: [
        pw.SizedBox(height: 14),
        pw.Row(
          children: [
            linha('Responsável pela medição'),
            pw.SizedBox(width: 24),
            linha('Empreiteiro / Conferente'),
          ],
        ),
        pw.SizedBox(height: 5),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              '${record.servicoNome} | ${record.empreiteiroNome}',
              style: pw.TextStyle(
                font: pw.Font.helvetica(),
                fontSize: 7,
                color: _hex(0xFF999999),
              ),
            ),
            pw.Text(
              'Página ${ctx.pageNumber} de ${ctx.pagesCount}',
              style: pw.TextStyle(
                font: pw.Font.helvetica(),
                fontSize: 7,
                color: _hex(0xFF999999),
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _medicaoCapa(
    MedicaoCampoRecord record,
    MedicaoResumo resumo,
    String responsavel,
    DateTime geradoEm,
  ) {
    final periodo = record.periodo.trim().isEmpty ? '-' : record.periodo.trim();
    final pasta = '${nomeMes(record.mes)}/${record.ano}';
    pw.Widget campo(String label, String valor) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 95,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                font: pw.Font.helvetica(),
                fontSize: 8,
                color: _hex(0xFF777777),
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              valor,
              style: pw.TextStyle(
                font: pw.Font.helveticaBold(),
                fontSize: 10,
                color: _hex(0xFF1A1A1A),
              ),
            ),
          ),
        ],
      ),
    );

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _hex(0xFF1A1A1A), width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          campo('OBRA', record.obra),
          campo('SERVIÇO', '${record.servicoCodigo} - ${record.servicoNome}'),
          campo('EMPREITEIRO', record.empreiteiroNome),
          campo('MEDIÇÃO / PERÍODO', periodo),
          campo('PASTA', pasta),
          campo('GERADO EM', _formatDate(geradoEm)),
          campo('RESPONSÁVEL', responsavel),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _resumoPill('Apartamentos', '${resumo.totalAptos}', _hex(0xFF1A1A1A)),
              _resumoPill('Conferidos', '${resumo.conferidos}', _hex(0xFF166534)),
              _resumoPill('Pendentes', '${resumo.pendentes}', _hex(0xFF92400E)),
              _resumoPill('Com problema', '${resumo.comProblema}', _hex(0xFF991B1B)),
              _resumoPill('Fotos', '${resumo.totalFotos}', _hex(0xFF1A1A1A)),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _medicaoTabelaResumo(List<MedicaoCampoApto> aptos) {
    PdfColor corStatus(String s) {
      switch (MedicaoStatus.normalize(s)) {
        case MedicaoStatus.conferido:
          return _hex(0xFF166534);
        case MedicaoStatus.problema:
          return _hex(0xFF991B1B);
        default:
          return _hex(0xFF92400E);
      }
    }

    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: pw.BoxDecoration(color: _hex(0xFFE8E8E8)),
        children: [
          _ncHeaderCell('TORRE', align: pw.TextAlign.left),
          _ncHeaderCell('LOCAL', align: pw.TextAlign.center),
          _ncHeaderCell('STATUS', align: pw.TextAlign.left),
          _ncHeaderCell('OBSERVAÇÃO', align: pw.TextAlign.left),
          _ncHeaderCell('FOTOS', align: pw.TextAlign.center),
        ],
      ),
      for (final a in aptos)
        pw.TableRow(
          children: [
            _tableCell(a.torre, align: pw.TextAlign.left, fontSize: 8, color: _hex(0xFF1A1A1A)),
            _tableCell(a.label, align: pw.TextAlign.center, fontSize: 8, color: _hex(0xFF1A1A1A)),
            _tableCell(
              MedicaoStatus.label(a.status),
              align: pw.TextAlign.left,
              fontSize: 8,
              color: corStatus(a.status),
            ),
            _tableCell(a.observacao, align: pw.TextAlign.left, fontSize: 8, color: _hex(0xFF1A1A1A)),
            _tableCell('${a.fotos.length}', align: pw.TextAlign.center, fontSize: 8, color: _hex(0xFF1A1A1A)),
          ],
        ),
    ];

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _hex(0xFF1A1A1A), width: 1),
      ),
      child: pw.Table(
        border: pw.TableBorder(
          horizontalInside: pw.BorderSide(color: _hex(0xFFDDDDDD), width: 1),
          verticalInside: pw.BorderSide(color: _hex(0xFFDDDDDD), width: 1),
        ),
        columnWidths: {
          0: const pw.FlexColumnWidth(1.2),
          1: const pw.FlexColumnWidth(0.8),
          2: const pw.FlexColumnWidth(1.4),
          3: const pw.FlexColumnWidth(3.5),
          4: const pw.FlexColumnWidth(0.7),
        },
        children: rows,
      ),
    );
  }

  pw.Widget _medicaoAptoTitulo(MedicaoCampoApto apto) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      color: _hex(0xFFE8E8E8),
      child: pw.Text(
        '${rotuloLocalMedicao(apto.label).toUpperCase()} | ${apto.torre} | ${MedicaoStatus.label(apto.status)}',
        style: pw.TextStyle(
          font: pw.Font.helveticaBold(),
          fontSize: 9,
          color: _hex(0xFF1A1A1A),
        ),
      ),
    );
  }

  pw.Widget _medicaoFotoCelula(MedicaoCampoFoto foto, Uint8List? bytes) {
    final pw.Widget conteudo;
    if (bytes == null || bytes.isEmpty) {
      conteudo = pw.Text(
        'Foto indisponível neste aparelho',
        style: pw.TextStyle(
          font: pw.Font.helvetica(),
          fontSize: 8,
          color: _hex(0xFF999999),
        ),
      );
    } else {
      conteudo = pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.contain);
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          height: 170,
          alignment: pw.Alignment.center,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _hex(0xFFCCCCCC), width: 0.5),
          ),
          child: conteudo,
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          foto.legenda,
          style: pw.TextStyle(
            font: pw.Font.helvetica(),
            fontSize: 6.5,
            color: _hex(0xFF444444),
          ),
        ),
      ],
    );
  }

  void _addResumoMedicaoPage(pw.Document pdf, _FvsPdfPayload payload) {
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 32),
        header: (ctx) {
          if (ctx.pageNumber != 1) return pw.SizedBox.shrink();
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader(payload, folhaText: 'Comprovação de medição'),
              pw.SizedBox(height: 8),
              _buildMetaGrid(payload),
            ],
          );
        },
        footer: (ctx) => _buildFooter(payload),
        build: (ctx) {
          final content = <pw.Widget>[
            pw.SizedBox(height: 10),
            _buildResumoCountsSection(payload),
          ];

          if (payload.items.isNotEmpty) {
            content.add(pw.SizedBox(height: 10));
            content.add(_buildSectionTitle('ITENS VERIFICADOS'));
            content.add(_buildItemsStatusTable(payload.items));
          }

          if (payload.photos.isNotEmpty) {
            content.add(pw.SizedBox(height: 10));
            content.add(_buildSectionTitle('REGISTRO FOTOGRÁFICO'));
            content.add(_buildPhotosSection(payload.photos));
          }

          return content;
        },
      ),
    );
  }

  pw.Widget _buildResumoCountsSection(_FvsPdfPayload payload) {
    var ok = 0, nok = 0, okAfterFix = 0, pending = 0;
    for (final item in payload.items) {
      switch (_normalizeStatus(item.status)) {
        case 'ok':
          ok++;
          break;
        case 'nok':
          nok++;
          break;
        case 'okafterfix':
          okAfterFix++;
          break;
        default:
          pending++;
      }
    }
    final total = payload.items.length;
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _hex(0xFF1A1A1A), width: 1),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _resumoPill('Itens verificados', '$total', _hex(0xFF1A1A1A)),
          _resumoPill('Conforme (O)', '$ok', _hex(0xFF166534)),
          _resumoPill('Corrigido (XO)', '$okAfterFix', _hex(0xFF92400E)),
          _resumoPill('NC aberta (X)', '$nok', _hex(0xFF991B1B)),
          if (pending > 0) _resumoPill('Pendente', '$pending', _hex(0xFF555555)),
        ],
      ),
    );
  }

  pw.Widget _resumoPill(String label, String value, PdfColor color) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(
            font: pw.Font.helveticaBold(),
            fontSize: 16,
            color: color,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          label,
          style: pw.TextStyle(
            font: pw.Font.helvetica(),
            fontSize: 7.5,
            color: _hex(0xFF777777),
          ),
        ),
      ],
    );
  }

  /// Lista TODOS os itens do checklist (não só os com problema) — pedido do
  /// usuário em 2026-10-01 depois de ver a primeira versão só com o resumo:
  /// "está só o resumo, quero os itens". Mantém a contagem geral como
  /// resumo no topo, mas essa tabela é o corpo principal da página.
  pw.Widget _buildItemsStatusTable(List<InspectionItemResult> items) {
    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: pw.BoxDecoration(color: _hex(0xFFE8E8E8)),
        children: [
          _ncHeaderCell('N°', align: pw.TextAlign.center),
          _ncHeaderCell('ITEM / DESCRIÇÃO', align: pw.TextAlign.left),
          _ncHeaderCell('STATUS', align: pw.TextAlign.center),
          _ncHeaderCell('OBSERVAÇÃO', align: pw.TextAlign.left),
        ],
      ),
    ];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final status = _normalizeStatus(item.status);
      final String symbol;
      final PdfColor color;
      switch (status) {
        case 'ok':
          symbol = 'O';
          color = _hex(0xFF166534);
          break;
        case 'nok':
          symbol = 'X';
          color = _hex(0xFF991B1B);
          break;
        case 'okafterfix':
          symbol = 'XO';
          color = _hex(0xFF92400E);
          break;
        default:
          symbol = '-';
          color = _hex(0xFF555555);
      }
      rows.add(
        pw.TableRow(
          children: [
            _tableCell(
              (i + 1).toString().padLeft(2, '0'),
              align: pw.TextAlign.center,
              fontSize: 8,
              color: _hex(0xFF1A1A1A),
            ),
            _tableCell(
              item.descricao,
              align: pw.TextAlign.left,
              fontSize: 8,
              color: _hex(0xFF1A1A1A),
            ),
            _tableCell(
              symbol,
              align: pw.TextAlign.center,
              fontSize: 8,
              color: color,
            ),
            _tableCell(
              item.obs,
              align: pw.TextAlign.left,
              fontSize: 8,
              color: _hex(0xFF1A1A1A),
            ),
          ],
        ),
      );
    }
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _hex(0xFF1A1A1A), width: 1),
      ),
      child: pw.Table(
        border: pw.TableBorder(
          horizontalInside: pw.BorderSide(color: _hex(0xFFDDDDDD), width: 1),
          verticalInside: pw.BorderSide(color: _hex(0xFFDDDDDD), width: 1),
        ),
        columnWidths: {
          0: const pw.FlexColumnWidth(0.4),
          1: const pw.FlexColumnWidth(3),
          2: const pw.FlexColumnWidth(0.8),
          3: const pw.FlexColumnWidth(3),
        },
        children: rows,
      ),
    );
  }

  Future<pw.Document> _buildConsolidadoPdfDoc({
    required String projectId,
    required String obraFixa,
    required String torre,
    required String fvsCodigo,
    String? fvsNomeOverride,
    String? operationalSheetId,
    String? operationalSheetLabel,
    required List<InspectionRecord> sourceRecords,
    required bool includeDrafts,
  }) async {
    final selectedOperationalSheetId = (operationalSheetId ?? '').trim();
    final filtered = sourceRecords.where((r) {
      if (r.projectId != projectId) return false;
      if (r.obra != obraFixa) return false;
      if (r.torre != torre) return false;
      if (r.fvsCodigo != fvsCodigo) return false;
      if (selectedOperationalSheetId.isNotEmpty &&
          (r.operationalSheetId ?? '').trim() != selectedOperationalSheetId) {
        return false;
      }
      if (r.deleted) return false;
      if (!includeDrafts && r.isDraft) return false;
      return true;
    }).toList();

    filtered.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final fvsNome = _stripNonPrintable(
      filtered.isNotEmpty
          ? filtered.first.fvsNome
          : (fvsNomeOverride?.trim().isNotEmpty == true
                ? fvsNomeOverride!.trim()
                : ''),
    );

    final latestByLocation = <String, InspectionRecord>{};
    for (final record in filtered) {
      final location = _displayLocation(record);
      final current = latestByLocation[location];
      if (current == null || record.updatedAt.isAfter(current.updatedAt)) {
        latestByLocation[location] = record;
      }
    }

    final pdf = pw.Document();
    final indexedLocations = latestByLocation.keys
        .toList()
        .asMap()
        .entries
        .toList();
    indexedLocations.sort((a, b) {
      final aNumber = _extractLocationOrderNumber(a.value);
      final bNumber = _extractLocationOrderNumber(b.value);

      if (aNumber != null && bNumber != null) {
        final byNumber = aNumber.compareTo(bNumber);
        if (byNumber != 0) return byNumber;
        return a.key.compareTo(b.key);
      }
      if (aNumber != null) return -1;
      if (bNumber != null) return 1;

      // não numéricos no final, mantendo ordem estável de entrada.
      return a.key.compareTo(b.key);
    });

    final allLocations = indexedLocations
        .map((entry) => entry.value)
        .toList(growable: false);
    final orderedInspections = allLocations
        .map((location) => latestByLocation[location])
        .whereType<InspectionRecord>()
        .toList(growable: false);

    final masterItems = orderedInspections.isEmpty
        ? const <InspectionItemResult>[]
        : orderedInspections.first.itens;

    final responsibleName = orderedInspections.isEmpty
        ? '—'
        : _safe(orderedInspections.first.actionByName);

    final consolidatedDate = orderedInspections.isEmpty
        ? DateTime.now()
        : reportInspectionLastActionAt(orderedInspections.first);

    final isSingleRecord = orderedInspections.length == 1;
    final consolidatedPayload = _FvsPdfPayload(
      obraNome: _safe(obraFixa),
      tower: _safe(torre),
      location: isSingleRecord
          ? _safe(_displayLocation(orderedInspections.first))
          : '—',
      fvsCode: _safe(fvsCodigo),
      fvsName: _safe(fvsNome),
      operationalSheetLabel: _safe(
        (operationalSheetLabel ?? '').trim().isNotEmpty
            ? operationalSheetLabel!
            : (selectedOperationalSheetId.isNotEmpty
                  ? 'Folha operacional selecionada'
                  : ''),
      ),
      inspectionDate: consolidatedDate,
      inspectorName: responsibleName,
      statusLabel: isSingleRecord
          ? reportInspectionStatusLabel(orderedInspections.first)
          : 'Consolidado',
      items: masterItems,
      photos: const [],
      openedNc: false,
      generalNotes: '',
    );

    if (masterItems.isEmpty || orderedInspections.isEmpty) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Relatório Consolidado de FVS',
                style: pw.TextStyle(
                  fontSize: 15,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text('Obra: $obraFixa • Torre: $torre'),
              pw.Text('FVS: $fvsCodigo${fvsNome.isEmpty ? '' : ' - $fvsNome'}'),
              if ((operationalSheetLabel ?? '').trim().isNotEmpty)
                pw.Text('Folha operacional: ${operationalSheetLabel!.trim()}'),
              pw.Text('Data: ${_formatDate(DateTime.now())}'),
              pw.SizedBox(height: 10),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                ),
                child: pw.Text(
                  'Sem dados para a combinação Torre/FVS selecionada.',
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      const maxApartmentsPerBlock = 9;
      final rawBlocks = _chunkList<InspectionRecord>(
        orderedInspections,
        maxApartmentsPerBlock,
      );
      // Pad last block so all blocks have the same column count.
      final blocks = rawBlocks.map((block) {
        final padded = block.map<InspectionRecord?>((r) => r).toList();
        while (padded.length < maxApartmentsPerBlock) {
          padded.add(null);
        }
        return padded;
      }).toList();

      final ncRows = _buildConsolidatedNcRows(
        masterItems: masterItems,
        inspections: orderedInspections,
      );

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 32),
          header: (ctx) => _buildConsolidatedHeader(ctx, consolidatedPayload),
          footer: (ctx) => _buildConsolidatedFooter(ctx, consolidatedPayload),
          build: (context) {
            final widgets = <pw.Widget>[
              _buildConsolidatedMetaGrid(consolidatedPayload),
              pw.SizedBox(height: 6),
              _buildLegend(),
              pw.SizedBox(height: 6),
              _buildConsolidatedSectionTitle(),
            ];

            for (var i = 0; i < blocks.length; i++) {
              final estimatedHeight = _estimateConsolidatedBlockHeight(
                masterItems.length,
              );
              widgets.add(pw.NewPage(freeSpace: estimatedHeight + 40));
              widgets.addAll(
                _buildConsolidatedBlockWidgets(
                  masterItems: masterItems,
                  blockInspections: blocks[i],
                ),
              );
              if (i < blocks.length - 1) {
                widgets.add(pw.SizedBox(height: 10));
              }
            }

            widgets.add(pw.SizedBox(height: 12));
            widgets.add(
              pw.Text(
                'Nao conformidades',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            );
            widgets.add(pw.SizedBox(height: 4));
            widgets.add(_buildNcTable(ncRows));
            widgets.add(pw.SizedBox(height: 12));
            widgets.add(_buildConsolidatedGeneralNotesSection(''));
            widgets.add(_buildConsolidatedSignaturesBlock());

            return widgets;
          },
        ),
      );
    }

    return pdf;
  }

  pw.Widget _buildOperationalSheetsSummary(List<InspectionRecord> inspections) {
    final grouped = <String, int>{};
    for (final record in inspections) {
      final key = (record.operationalSheetLabel ?? '').trim().isEmpty
          ? 'Sem folha operacional'
          : record.operationalSheetLabel!.trim();
      grouped[key] = (grouped[key] ?? 0) + 1;
    }

    final ordered = grouped.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(color: PdfColors.grey400, width: 0.4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Folhas operacionais incluídas',
            style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 9),
          ),
          pw.SizedBox(height: 4),
          ...ordered.map(
            (entry) => pw.Text(
              '• ${entry.key} (${entry.value} local${entry.value > 1 ? 'is' : ''})',
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildConsolidatedHeader(pw.Context ctx, _FvsPdfPayload payload) {
    final code = payload.fvsCode.replaceAll('.', '');
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              children: [
                pw.Container(
                  width: 30,
                  height: 30,
                  color: _hex(0xFF1A1A1A),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    'FVS',
                    style: pw.TextStyle(
                      font: pw.Font.helveticaBold(),
                      fontSize: 9,
                      color: PdfColors.white,
                    ),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Ficha de Verificação de Serviço',
                      style: pw.TextStyle(
                        font: pw.Font.helveticaBold(),
                        fontSize: 13,
                        color: _hex(0xFF1A1A1A),
                      ),
                    ),
                    pw.SizedBox(height: 1),
                    pw.Text(
                      'RELATÓRIO CONSOLIDADO DE INSPEÇÃO DE OBRA',
                      style: pw.TextStyle(
                        font: pw.Font.helvetica(),
                        fontSize: 7.5,
                        color: _hex(0xFF777777),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'Doc.: FVS-$code-CONS',
                  style: pw.TextStyle(
                    font: pw.Font.helvetica(),
                    fontSize: 8,
                    color: _hex(0xFF777777),
                  ),
                ),
                pw.Text(
                  'Rev.: 00  |  Folha ${ctx.pageNumber}/${ctx.pagesCount}',
                  style: pw.TextStyle(
                    font: pw.Font.helvetica(),
                    fontSize: 8,
                    color: _hex(0xFF777777),
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Container(height: 2, color: _hex(0xFF1A1A1A)),
        pw.SizedBox(height: 6),
      ],
    );
  }

  pw.Widget _buildConsolidatedMetaGrid(_FvsPdfPayload payload) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _hex(0xFF1A1A1A), width: 1),
      ),
      child: pw.Row(
        children: [
          _buildConsolidatedMetaCell('OBRA', payload.obraNome),
          _buildConsolidatedMetaCell('TORRE', payload.tower),
          _buildConsolidatedMetaCell(
            'FVS',
            '${payload.fvsCode} - ${payload.fvsName}',
          ),
          _buildConsolidatedMetaCell(
            'DATA',
            _formatDateOnly(payload.inspectionDate),
          ),
          _buildConsolidatedMetaCell('RESPONSÁVEL', '', isLast: true),
        ],
      ),
    );
  }

  pw.Widget _buildConsolidatedStatusesSection(
    List<InspectionRecord> inspections,
  ) {
    final rows = inspections
        .map(
          (record) => (
            local: _displayLocation(record),
            status: reportInspectionStatusLabel(record),
          ),
        )
        .toList(growable: false);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Status por local',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Wrap(
          spacing: 8,
          runSpacing: 6,
          children: rows
              .map(
                (row) => pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(4),
                    ),
                  ),
                  child: pw.Text(
                    '${row.local}: ${row.status}',
                    style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 8),
                  ),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }

  pw.Widget _buildConsolidatedMetaCell(
    String label,
    String value, {
    bool isLast = false,
  }) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        decoration: isLast
            ? null
            : pw.BoxDecoration(
                border: pw.Border(
                  right: pw.BorderSide(color: _hex(0xFF1A1A1A), width: 1),
                ),
              ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                font: pw.Font.helvetica(),
                fontSize: 7,
                color: _hex(0xFF777777),
                letterSpacing: 0.6,
              ),
            ),
            pw.SizedBox(height: 2),
            if (value.isEmpty)
              pw.Container(
                height: 1,
                width: double.infinity,
                color: _hex(0xFF1A1A1A),
                margin: const pw.EdgeInsets.only(top: 8),
              )
            else
              pw.Text(
                _safe(value),
                style: pw.TextStyle(
                  font: pw.Font.helveticaBold(),
                  fontSize: 9,
                  color: _hex(0xFF1A1A1A),
                ),
              ),
          ],
        ),
      ),
    );
  }

  double _estimateConsolidatedBlockHeight(int itemCount) {
    return 20 + (itemCount * 18);
  }

  pw.Widget _buildConsolidatedSectionTitle() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: pw.BoxDecoration(
        color: _hex(0xFFE8E8E8),
        border: pw.Border(
          top: pw.BorderSide(color: _hex(0xFF1A1A1A), width: 1),
          left: pw.BorderSide(color: _hex(0xFF1A1A1A), width: 1),
          right: pw.BorderSide(color: _hex(0xFF1A1A1A), width: 1),
        ),
      ),
      child: pw.Text(
        'TABELA CONSOLIDADA DE INSPEÇÃO',
        style: pw.TextStyle(
          font: pw.Font.helveticaBold(),
          fontSize: 8,
          color: _hex(0xFF1A1A1A),
        ),
      ),
    );
  }

  List<pw.Widget> _buildConsolidatedBlockWidgets({
    required List<InspectionItemResult> masterItems,
    required List<InspectionRecord?> blockInspections,
  }) {
    if (masterItems.isEmpty || blockInspections.isEmpty) {
      return const <pw.Widget>[];
    }

    return <pw.Widget>[
      _buildConsolidatedBlockTable(
        masterItems: masterItems,
        rowStart: 0,
        rowEndExclusive: masterItems.length,
        blockInspections: blockInspections,
      ),
    ];
  }

  pw.Widget _buildConsolidatedBlockTable({
    required List<InspectionItemResult> masterItems,
    required int rowStart,
    required int rowEndExclusive,
    required List<InspectionRecord?> blockInspections,
  }) {
    final rows = <pw.TableRow>[];
    final locations = blockInspections
        .map((r) => r != null ? _displayLocation(r) : '')
        .toList(growable: false);

    rows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(color: _hex(0xFF1A1A1A)),
        children: [
          _consolidatedHeaderCell('ITEM', align: pw.TextAlign.left),
          ...locations.map(
            (location) =>
                _consolidatedHeaderCell(location, align: pw.TextAlign.center),
          ),
        ],
      ),
    );

    for (var itemIndex = rowStart; itemIndex < rowEndExclusive; itemIndex++) {
      final item = masterItems[itemIndex];
      final zebra = (itemIndex % 2 == 1) ? _hex(0xFFF9F9F9) : PdfColors.white;
      rows.add(
        pw.TableRow(
          children: [
            _consolidatedItemCell(
              '${itemIndex + 1}. ${item.descricao.trim()}',
              zebra: zebra,
            ),
            ...blockInspections.map((inspection) {
              if (inspection == null)
                return _consolidatedStatusCell(symbol: '');
              final rawStatus = itemIndex < inspection.itens.length
                  ? inspection.itens[itemIndex].status
                  : null;
              final symbol = _statusSymbolFromRaw(rawStatus);
              return _consolidatedStatusCell(symbol: symbol);
            }),
          ],
        ),
      );
    }

    final columnWidths = <int, pw.TableColumnWidth>{
      0: const pw.FixedColumnWidth(160),
    };
    for (var i = 1; i <= blockInspections.length; i++) {
      columnWidths[i] = const pw.FixedColumnWidth(40);
    }

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _hex(0xFF1A1A1A), width: 1),
      ),
      child: pw.Table(
        border: pw.TableBorder(
          horizontalInside: pw.BorderSide(color: _hex(0xFFCCCCCC), width: 1),
          verticalInside: pw.BorderSide(color: _hex(0xFFCCCCCC), width: 1),
        ),
        columnWidths: columnWidths,
        children: rows,
      ),
    );
  }

  pw.Widget _consolidatedHeaderCell(
    String text, {
    required pw.TextAlign align,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          font: pw.Font.helveticaBold(),
          fontSize: 8,
          color: PdfColors.white,
        ),
      ),
    );
  }

  pw.Widget _consolidatedItemCell(String text, {required PdfColor zebra}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      constraints: const pw.BoxConstraints(minHeight: 18),
      decoration: pw.BoxDecoration(
        color: zebra,
        border: pw.Border(
          right: pw.BorderSide(color: _hex(0xFF1A1A1A), width: 1),
        ),
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: pw.Font.helvetica(),
          fontSize: 8,
          color: _hex(0xFF1A1A1A),
        ),
      ),
    );
  }

  pw.Widget _consolidatedStatusCell({required String symbol}) {
    return pw.Container(
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      constraints: const pw.BoxConstraints(minHeight: 18),
      color: _statusSymbolBackground(symbol),
      child: pw.Text(
        symbol,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          font: pw.Font.helveticaBold(),
          fontSize: 9,
          color: _statusSymbolColor(symbol),
        ),
      ),
    );
  }

  PdfColor _statusSymbolBackground(String symbol) {
    switch (symbol) {
      case 'O':
        return _hex(0xFFE8F5E9);
      case 'X':
        return _hex(0xFFFFEBEE);
      case 'XO':
        return _hex(0xFFFFF8E1);
      default:
        return _hex(0xFFF3F4F6);
    }
  }

  List<_NcGroupedRow> _buildConsolidatedNcRows({
    required List<InspectionItemResult> masterItems,
    required List<InspectionRecord> inspections,
  }) {
    final rows = <_NcGroupedRow>[];

    for (var itemIndex = 0; itemIndex < masterItems.length; itemIndex++) {
      final itemDescription = masterItems[itemIndex].descricao.trim();

      for (final inspection in inspections) {
        if (itemIndex >= inspection.itens.length) continue;
        final item = inspection.itens[itemIndex];
        if (_statusSymbolFromRaw(item.status) != 'X') continue;

        rows.add(
          _NcGroupedRow(
            itemDescricao: itemDescription,
            observacao: item.obs.trim(),
            prazo: '',
            responsavel: 'Equipe',
            local: _displayLocation(inspection),
          ),
        );
      }
    }

    rows.sort((a, b) {
      final byLocal = _locationSortCompare(a.local, b.local);
      if (byLocal != 0) return byLocal;
      return a.itemDescricao.toLowerCase().compareTo(
        b.itemDescricao.toLowerCase(),
      );
    });
    return rows;
  }

  String _buildConsolidatedNotes(List<InspectionRecord> inspections) {
    final notes = <String>[];
    for (final inspection in inspections) {
      for (final item in inspection.itens) {
        final note = item.obs.trim();
        if (note.isEmpty) continue;
        notes.add(note);
      }
    }

    if (notes.isEmpty) return '';
    final unique = <String>[];
    final seen = <String>{};
    for (final note in notes) {
      if (!seen.add(note)) continue;
      unique.add(note);
    }
    return unique.join('\n');
  }

  pw.Widget _buildNcTable(List<_NcGroupedRow> rows) {
    final dataRows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.red100),
        children: [
          _ncTableHeaderCell('N', align: pw.TextAlign.center),
          _ncTableHeaderCell('Local', align: pw.TextAlign.left),
          _ncTableHeaderCell('ITEM / DESCRICAO', align: pw.TextAlign.left),
          _ncTableHeaderCell('Observacao', align: pw.TextAlign.left),
          _ncTableHeaderCell('RESP', align: pw.TextAlign.left),
        ],
      ),
    ];

    if (rows.isEmpty) {
      dataRows.add(
        pw.TableRow(
          children: [
            _ncTableCell(''),
            _ncTableCell(''),
            _ncTableCell('Sem nao conformidades.'),
            _ncTableCell(''),
            _ncTableCell(''),
          ],
        ),
      );
    } else {
      for (var i = 0; i < rows.length; i++) {
        final row = rows[i];
        dataRows.add(
          pw.TableRow(
            children: [
              _ncTableCell('${i + 1}'),
              _ncTableCell(row.local),
              _ncTableCell(row.itemDescricao),
              _ncTableCell(row.observacao),
              _ncTableCell(row.responsavel),
            ],
          ),
        );
      }
    }

    return pw.Table(
      border: pw.TableBorder(
        top: pw.BorderSide(color: PdfColors.red300, width: 0.6),
        bottom: pw.BorderSide(color: PdfColors.red300, width: 0.6),
        left: pw.BorderSide(color: PdfColors.red300, width: 0.6),
        right: pw.BorderSide(color: PdfColors.red300, width: 0.6),
        horizontalInside: const pw.BorderSide(
          color: PdfColors.red200,
          width: 0.25,
        ),
        verticalInside: const pw.BorderSide(
          color: PdfColors.red200,
          width: 0.25,
        ),
      ),
      columnWidths: {
        0: const pw.FixedColumnWidth(24),
        1: const pw.FlexColumnWidth(1.6),
        2: const pw.FlexColumnWidth(2.4),
        3: const pw.FlexColumnWidth(2.6),
        4: const pw.FlexColumnWidth(1.2),
      },
      children: dataRows,
    );
  }

  pw.Widget _ncTableHeaderCell(String text, {required pw.TextAlign align}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          font: pw.Font.helveticaBold(),
          fontSize: 8,
          color: _hex(0xFF7F1D1D),
        ),
      ),
    );
  }

  pw.Widget _ncTableCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: pw.Font.helvetica(),
          fontSize: 8,
          color: _hex(0xFF1A1A1A),
        ),
      ),
    );
  }

  pw.Widget _buildHeader(_FvsPdfPayload payload, {required String folhaText}) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              children: [
                pw.Container(
                  width: 30,
                  height: 30,
                  color: _hex(0xFF1A1A1A),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    'FVS',
                    style: pw.TextStyle(
                      font: pw.Font.helveticaBold(),
                      fontSize: 9,
                      color: PdfColors.white,
                    ),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Ficha de Verificação de Serviço',
                      style: pw.TextStyle(
                        font: pw.Font.helveticaBold(),
                        fontSize: 13,
                        color: _hex(0xFF1A1A1A),
                      ),
                    ),
                    pw.SizedBox(height: 1),
                    pw.Text(
                      'RELATÓRIO DE INSPEÇÃO DE OBRA',
                      style: pw.TextStyle(
                        font: pw.Font.helvetica(),
                        fontSize: 7.5,
                        color: _hex(0xFF777777),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'Doc.: ${_buildDocumentCode(payload)}',
                  style: pw.TextStyle(
                    font: pw.Font.helvetica(),
                    fontSize: 8,
                    color: _hex(0xFF777777),
                  ),
                ),
                pw.Text(
                  'Rev.: 00  |  $folhaText',
                  style: pw.TextStyle(
                    font: pw.Font.helvetica(),
                    fontSize: 8,
                    color: _hex(0xFF777777),
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Container(height: 2, color: _hex(0xFF1A1A1A)),
      ],
    );
  }

  pw.Widget _buildMetaGrid(_FvsPdfPayload payload) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _hex(0xFF1A1A1A), width: 1),
      ),
      child: pw.Row(
        children: [
          _metaCellV2('OBRA', payload.obraNome),
          _metaCellV2('TORRE', payload.tower),
          _metaCellV2('LOCAL / APTO', payload.location),
          _metaCellV2('FVS', '${payload.fvsCode} - ${payload.fvsName}'),
          _metaCellV2('STATUS', payload.statusLabel),
          _metaCellV2('DATA', _formatDateOnly(payload.inspectionDate)),
          _metaCellV2('RESPONSÁVEL', payload.inspectorName, isLast: true),
        ],
      ),
    );
  }

  pw.Widget _metaCellV2(String label, String value, {bool isLast = false}) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: isLast
            ? null
            : const pw.BoxDecoration(
                border: pw.Border(
                  right: pw.BorderSide(width: 1, color: PdfColors.black),
                ),
              ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                font: pw.Font.helvetica(),
                fontSize: 7,
                color: _hex(0xFF777777),
                letterSpacing: 0.6,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              _safe(value),
              maxLines: 2,
              style: pw.TextStyle(
                font: pw.Font.helveticaBold(),
                fontSize: 9,
                color: _hex(0xFF1A1A1A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildLegend() {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        children: [
          _legendItemV2('O', 'Conforme', _hex(0xFF166534)),
          pw.SizedBox(width: 14),
          _legendItemV2('X', 'Não conforme', _hex(0xFF991B1B)),
          pw.SizedBox(width: 14),
          _legendItemV2('XO', 'Conforme após correção', _hex(0xFF92400E)),
          pw.SizedBox(width: 14),
          _legendItemV2('-', 'Falta inspeção', _hex(0xFF555555)),
        ],
      ),
    );
  }

  pw.Widget _legendItemV2(String symbol, String label, PdfColor color) {
    return pw.Row(
      children: [
        pw.Text(
          symbol,
          style: pw.TextStyle(
            font: pw.Font.helveticaBold(),
            fontSize: 9,
            color: color,
          ),
        ),
        pw.SizedBox(width: 4),
        pw.Text(
          label,
          style: pw.TextStyle(
            font: pw.Font.helvetica(),
            fontSize: 8,
            color: _hex(0xFF777777),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildSectionTitle(String title) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: pw.BoxDecoration(
        color: _hex(0xFFE8E8E8),
        border: pw.Border(
          top: pw.BorderSide(color: _hex(0xFF1A1A1A), width: 1),
          left: pw.BorderSide(color: _hex(0xFF1A1A1A), width: 1),
          right: pw.BorderSide(color: _hex(0xFF1A1A1A), width: 1),
        ),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          font: pw.Font.helveticaBold(),
          fontSize: 7.5,
          color: _hex(0xFF1A1A1A),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  _FvsPdfMatrixData _buildMatrixReportData(_FvsPdfPayload payload) {
    final source = Hive.box<InspectionRecord>('inspections').values.where((
      record,
    ) {
      if (record.fvsCodigo.trim() != payload.fvsCode.trim()) return false;
      if (record.torre.trim() != payload.tower.trim()) return false;
      if (record.obra.trim() != payload.obraNome.trim()) return false;
      return isInspectionEligibleForReport(record);
    }).toList();

    source.sort((a, b) {
      final byDate = a.businessDate.compareTo(b.businessDate);
      if (byDate != 0) return byDate;
      return a.updatedAt.compareTo(b.updatedAt);
    });

    final latestByLocation = <String, InspectionRecord>{};
    for (final record in source) {
      final key = _displayLocation(record);
      final previous = latestByLocation[key];
      if (previous == null || record.updatedAt.isAfter(previous.updatedAt)) {
        latestByLocation[key] = record;
      }
    }

    final locations = latestByLocation.keys.toList()
      ..sort(_locationSortCompare);

    final itemDescriptions = <String>[];
    final seenDescriptions = <String>{};
    for (final record in latestByLocation.values) {
      for (final item in record.itens) {
        final desc = item.descricao.trim();
        if (desc.isEmpty) continue;
        if (seenDescriptions.add(desc)) {
          itemDescriptions.add(desc);
        }
      }
    }

    final rows = itemDescriptions
        .map<_FvsPdfMatrixRow>((itemDescription) {
          final statusByLocation = <String, String>{};
          for (final location in locations) {
            final record = latestByLocation[location];
            final matchedItem = record?.itens
                .where((e) => e.descricao.trim() == itemDescription)
                .cast<InspectionItemResult?>()
                .firstWhere((item) => item != null, orElse: () => null);
            final status = _statusSymbolFromRaw(matchedItem?.status);
            statusByLocation[location] = status;
          }
          return _FvsPdfMatrixRow(
            description: itemDescription,
            statusByLocation: statusByLocation,
          );
        })
        .toList(growable: false);

    return _FvsPdfMatrixData(locations: locations, rows: rows);
  }

  int _locationSortCompare(String a, String b) {
    final aNum = int.tryParse(a);
    final bNum = int.tryParse(b);
    if (aNum != null && bNum != null) {
      return aNum.compareTo(bNum);
    }
    if (aNum != null) return -1;
    if (bNum != null) return 1;
    return a.compareTo(b);
  }

  int? _extractLocationOrderNumber(String location) {
    final trimmed = location.trim();
    if (trimmed.isEmpty) return null;

    final direct = int.tryParse(trimmed);
    if (direct != null) return direct;

    final match = RegExp(r'\d+').firstMatch(trimmed);
    if (match == null) return null;

    return int.tryParse(match.group(0) ?? '');
  }

  pw.Widget _buildEmptyMatrixBody() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _hex(0xFF1A1A1A), width: 1),
      ),
      child: pw.Text(
        'Sem dados para montar a matriz desta FVS.',
        style: pw.TextStyle(
          font: pw.Font.helvetica(),
          fontSize: 8.5,
          color: _hex(0xFF444444),
        ),
      ),
    );
  }

  pw.Widget _buildMatrixBlockTable({
    required List<_FvsPdfMatrixRow> rows,
    required List<String> locations,
  }) {
    final tableRows = <pw.TableRow>[];

    tableRows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(color: _hex(0xFF1A1A1A)),
        children: [
          _matrixBlockHeaderCell('ITEM', align: pw.TextAlign.left),
          ...locations.map(
            (location) =>
                _matrixBlockHeaderCell(location, align: pw.TextAlign.center),
          ),
        ],
      ),
    );

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final zebra = i.isEven ? _hex(0xFFFFFFFF) : _hex(0xFFF9F9F9);
      tableRows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(color: zebra),
          children: [
            _matrixItemDescriptionCell(row.description),
            ...locations.map((location) {
              final symbol = row.statusByLocation[location] ?? '-';
              return _matrixStatusSymbolCell(symbol);
            }),
          ],
        ),
      );
    }

    final columnWidths = <int, pw.TableColumnWidth>{
      0: const pw.FixedColumnWidth(160),
    };
    for (var i = 1; i <= locations.length; i++) {
      columnWidths[i] = const pw.FixedColumnWidth(44);
    }

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _hex(0xFF1A1A1A), width: 1),
      ),
      child: pw.Table(
        border: pw.TableBorder(
          horizontalInside: pw.BorderSide(color: _hex(0xFFCCCCCC), width: 1),
          verticalInside: pw.BorderSide(color: _hex(0xFFCCCCCC), width: 1),
        ),
        columnWidths: columnWidths,
        children: tableRows,
      ),
    );
  }

  pw.Widget _matrixBlockHeaderCell(String text, {required pw.TextAlign align}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          font: pw.Font.helveticaBold(),
          fontSize: 8,
          color: PdfColors.white,
        ),
      ),
    );
  }

  pw.Widget _matrixItemDescriptionCell(String description) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Text(
        _truncate(description, 85),
        maxLines: 2,
        style: pw.TextStyle(
          font: pw.Font.helvetica(),
          fontSize: 8.5,
          color: _hex(0xFF1A1A1A),
        ),
      ),
    );
  }

  pw.Widget _matrixStatusSymbolCell(String symbol) {
    return pw.Container(
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Text(
        symbol,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          font: pw.Font.helveticaBold(),
          fontSize: 9,
          color: _statusSymbolColor(symbol),
        ),
      ),
    );
  }

  pw.Widget _tableCell(
    String text, {
    required pw.TextAlign align,
    required double fontSize,
    required PdfColor color,
    bool fallbackDash = true,
  }) {
    final normalized = text.trim();
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Text(
        normalized.isEmpty ? (fallbackDash ? '-' : '') : normalized,
        textAlign: align,
        style: pw.TextStyle(
          font: pw.Font.helvetica(),
          fontSize: fontSize,
          color: color,
        ),
      ),
    );
  }

  pw.Widget _buildPhotosSection(List<_PdfPhotoEntry> photos) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          left: pw.BorderSide(color: _hex(0xFF1A1A1A), width: 1),
          right: pw.BorderSide(color: _hex(0xFF1A1A1A), width: 1),
          bottom: pw.BorderSide(color: _hex(0xFF1A1A1A), width: 1),
        ),
      ),
      child: pw.Wrap(
        spacing: 6,
        runSpacing: 6,
        children: photos
            .map(
              (photo) => pw.Column(
                children: [
                  pw.Container(
                    width: 100,
                    height: 75,
                    child: pw.Image(
                      pw.MemoryImage(photo.bytes),
                      fit: pw.BoxFit.cover,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.SizedBox(
                    width: 100,
                    child: pw.Text(
                      photo.caption,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        font: pw.Font.helvetica(),
                        fontSize: 7,
                        color: _hex(0xFF777777),
                      ),
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }

  pw.Widget _buildNcSection(_FvsPdfPayload payload) {
    final ncs = payload.items
        .where((i) => _normalizeStatus(i.status) == 'nok')
        .toList();
    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: pw.BoxDecoration(color: _hex(0xFFFEF2F2)),
        children: [
          _ncHeaderCell('N°', align: pw.TextAlign.center),
          _ncHeaderCell('ITEM / DESCRIÇÃO', align: pw.TextAlign.left),
          _ncHeaderCell(
            'OBSERVAÇÃO / AÇÃO REQUERIDA',
            align: pw.TextAlign.left,
          ),
          _ncHeaderCell('RESP.', align: pw.TextAlign.left),
        ],
      ),
    ];

    if (ncs.isEmpty && payload.openedNc) {
      rows.add(
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(
                'NC registrada — sem itens detalhados nesta inspeção.',
                style: pw.TextStyle(
                  font: pw.Font.helvetica(),
                  fontSize: 8,
                  color: _hex(0xFFB91C1C),
                ),
              ),
            ),
            pw.SizedBox(),
            pw.SizedBox(),
            pw.SizedBox(),
          ],
        ),
      );
    } else {
      for (var i = 0; i < ncs.length; i++) {
        final nc = ncs[i];
        rows.add(
          pw.TableRow(
            children: [
              _tableCell(
                (i + 1).toString().padLeft(2, '0'),
                align: pw.TextAlign.center,
                fontSize: 8,
                color: _hex(0xFF1A1A1A),
              ),
              _tableCell(
                nc.descricao,
                align: pw.TextAlign.left,
                fontSize: 8,
                color: _hex(0xFF1A1A1A),
              ),
              _tableCell(
                nc.obs,
                align: pw.TextAlign.left,
                fontSize: 8,
                color: _hex(0xFF1A1A1A),
              ),
              _tableCell(
                'Equipe',
                align: pw.TextAlign.left,
                fontSize: 8,
                color: _hex(0xFF1A1A1A),
              ),
            ],
          ),
        );
      }
    }

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _hex(0xFF991B1B), width: 1),
      ),
      child: pw.Column(
        children: [
          pw.Container(
            width: double.infinity,
            color: _hex(0xFF991B1B),
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: pw.Text(
              'NÃO CONFORMIDADES IDENTIFICADAS',
              style: pw.TextStyle(
                font: pw.Font.helveticaBold(),
                fontSize: 7.5,
                color: PdfColors.white,
                letterSpacing: 0.8,
              ),
            ),
          ),
          pw.Table(
            border: pw.TableBorder(
              horizontalInside: pw.BorderSide(
                color: _hex(0xFFFDE8E8),
                width: 1,
              ),
              verticalInside: pw.BorderSide(color: _hex(0xFFFDE8E8), width: 1),
            ),
            columnWidths: {
              0: const pw.FlexColumnWidth(0.4),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FlexColumnWidth(3),
              3: const pw.FlexColumnWidth(1),
            },
            children: rows,
          ),
        ],
      ),
    );
  }

  pw.Widget _ncHeaderCell(String text, {required pw.TextAlign align}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          font: pw.Font.helveticaBold(),
          fontSize: 7.5,
          color: _hex(0xFF7F1D1D),
        ),
      ),
    );
  }

  pw.Widget _buildGeneralNotesSection(String notes) {
    final normalized = notes.trim();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('OBSERVAÇÕES GERAIS'),
        pw.Container(
          width: double.infinity,
          constraints: const pw.BoxConstraints(minHeight: 32),
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: pw.BoxDecoration(
            border: pw.Border(
              left: pw.BorderSide(color: _hex(0xFF1A1A1A), width: 1),
              right: pw.BorderSide(color: _hex(0xFF1A1A1A), width: 1),
              bottom: pw.BorderSide(color: _hex(0xFF1A1A1A), width: 1),
            ),
          ),
          child: normalized.isNotEmpty
              ? pw.Text(
                  normalized,
                  style: pw.TextStyle(
                    font: pw.Font.helvetica(),
                    fontSize: 8.5,
                    color: _hex(0xFF444444),
                  ),
                )
              : pw.Column(
                  children: [
                    _manualLine(),
                    pw.SizedBox(height: 10),
                    _manualLine(),
                    pw.SizedBox(height: 10),
                    _manualLine(),
                  ],
                ),
        ),
      ],
    );
  }

  pw.Widget _buildConsolidatedGeneralNotesSection(String notes) {
    final normalized = notes.trim();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: pw.BoxDecoration(
            color: _hex(0xFFE8E8E8),
            border: pw.Border(
              top: pw.BorderSide(color: _hex(0xFF1A1A1A), width: 1),
              left: pw.BorderSide(color: _hex(0xFF1A1A1A), width: 1),
              right: pw.BorderSide(color: _hex(0xFF1A1A1A), width: 1),
            ),
          ),
          child: pw.Text(
            'OBSERVAÇÕES GERAIS',
            style: pw.TextStyle(
              font: pw.Font.helveticaBold(),
              fontSize: 7.5,
              color: _hex(0xFF1A1A1A),
              letterSpacing: 0.8,
            ),
          ),
        ),
        pw.Container(
          width: double.infinity,
          constraints: const pw.BoxConstraints(minHeight: 60),
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border(
              left: pw.BorderSide(color: _hex(0xFF1A1A1A), width: 1),
              right: pw.BorderSide(color: _hex(0xFF1A1A1A), width: 1),
              bottom: pw.BorderSide(color: _hex(0xFF1A1A1A), width: 1),
            ),
          ),
          child: normalized.isEmpty
              ? pw.Column(
                  children: [
                    _manualLine(),
                    pw.SizedBox(height: 16),
                    _manualLine(),
                    pw.SizedBox(height: 16),
                    _manualLine(),
                  ],
                )
              : pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      normalized,
                      style: pw.TextStyle(
                        font: pw.Font.helvetica(),
                        fontSize: 8.5,
                        color: _hex(0xFF444444),
                        lineSpacing: 1.6,
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    _manualLine(),
                    pw.SizedBox(height: 16),
                    _manualLine(),
                  ],
                ),
        ),
      ],
    );
  }

  pw.Widget _manualLine() => pw.Container(height: 1, color: _hex(0xFFCCCCCC));

  pw.Widget _buildSignaturesBlock() {
    return pw.Column(
      children: [
        pw.Container(height: 1, color: _hex(0xFFCCCCCC)),
        pw.SizedBox(height: 8),
        pw.Row(
          children: [
            _signatureColumn('Inspetor responsável / CREA'),
            pw.SizedBox(width: 16),
            _signatureColumn('Empreiteiro / Encarregado'),
            pw.SizedBox(width: 16),
            _signatureColumn('Fiscal de obra / Data'),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildConsolidatedSignaturesBlock() {
    return pw.Column(
      children: [
        pw.SizedBox(height: 20),
        pw.Container(height: 1, color: _hex(0xFFCCCCCC)),
        pw.SizedBox(height: 8),
        pw.Row(
          children: [
            _signatureColumn('Inspetor responsável / CREA'),
            pw.SizedBox(width: 16),
            _signatureColumn('Empreiteiro / Encarregado'),
            pw.SizedBox(width: 16),
            _signatureColumn('Fiscal de obra / Data'),
          ],
        ),
      ],
    );
  }

  pw.Widget _signatureColumn(String label) {
    return pw.Expanded(
      child: pw.Column(
        children: [
          pw.Container(
            height: 22,
            decoration: pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: _hex(0xFF1A1A1A), width: 1),
              ),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            label,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              font: pw.Font.helvetica(),
              fontSize: 7.5,
              color: _hex(0xFF777777),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(_FvsPdfPayload payload) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 4),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: _hex(0xFFCCCCCC), width: 0.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'FVS-${payload.fvsCode} | ${payload.tower} | ${payload.location} | ${_formatDateOnly(payload.inspectionDate)}',
            style: pw.TextStyle(
              font: pw.Font.helvetica(),
              fontSize: 7,
              color: _hex(0xFFCCCCCC),
            ),
          ),
          pw.Text(
            'Documento de uso interno — Controle de qualidade de obra',
            style: pw.TextStyle(
              font: pw.Font.helvetica(),
              fontSize: 7,
              color: _hex(0xFFCCCCCC),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildConsolidatedFooter(pw.Context ctx, _FvsPdfPayload payload) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 4),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: _hex(0xFFCCCCCC), width: 0.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'FVS-${payload.fvsCode} | ${payload.tower} | ${_formatDateOnly(payload.inspectionDate)}',
            style: pw.TextStyle(
              font: pw.Font.helvetica(),
              fontSize: 7,
              color: _hex(0xFFAAAAAA),
            ),
          ),
          pw.Text(
            'Pagina ${ctx.pageNumber} de ${ctx.pagesCount} | Documento de uso interno',
            style: pw.TextStyle(
              font: pw.Font.helvetica(),
              fontSize: 7,
              color: _hex(0xFFAAAAAA),
            ),
          ),
        ],
      ),
    );
  }

  String _buildDocumentCode(_FvsPdfPayload payload) {
    final locationCode = payload.location
        .replaceAll(RegExp(r'\s+'), '')
        .toUpperCase();
    return 'FVS-${payload.fvsCode.replaceAll('.', '')}-$locationCode';
  }

  String _displayLocation(InspectionRecord record) {
    final ref = record.localRef?.trim();
    if (ref != null && ref.isNotEmpty) return _normalizeLocalLabel(ref);
    return record.apto.trim();
  }

  String _normalizeLocalLabel(String ref) {
    if (ref.startsWith('APTO_')) {
      final after = ref.substring(5);
      if (RegExp(r'^\d+$').hasMatch(after)) return after;
      if (after.contains('_')) {
        final parts = after.split('_');
        if (parts.length == 2) {
          final floor = parts[0];
          final unit = parts[1];
          final unitNum = int.tryParse(unit);
          if (unitNum != null) {
            final unitSuffix = unitNum.toString().padLeft(2, '0');
            return '$floor$unitSuffix';
          }
        }
      }
      return after.replaceAll('_', ' ');
    }
    if (ref.startsWith('STRUCT_')) return ref.substring(7).replaceAll('_', ' ');
    if (ref.startsWith('FACADE_')) return ref.substring(7).replaceAll('_', ' ');
    if (ref.startsWith('SECTOR_')) return ref.substring(7).replaceAll('_', ' ');
    if (ref.startsWith('FREE_')) return ref.substring(5).replaceAll('_', ' ');
    if (ref == 'ROOFTOP' || ref == 'COBERTURA') return 'Rooftop';
    return ref;
  }

  String _safe(String? input) {
    final value = (input ?? '').trim();
    return value.isEmpty ? '—' : value;
  }

  String _normalizeStatus(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    if (value == 'ok' ||
        value == 'nok' ||
        value == 'na' ||
        value == 'pending' ||
        value == 'okafterfix') {
      return value;
    }
    return 'pending';
  }

  PdfColor _hex(int color) => PdfColor.fromInt(color);

  String _truncate(String value, int maxChars) {
    final text = value.trim();
    if (text.length <= maxChars) return text;
    return '${text.substring(0, maxChars - 2)}...';
  }

  Future<File> generateMatrixByTorreFvs({
    required String projectId,
    required String obraFixa,
    required String torre,
    required String fvsCodigo,
    required List<InspectionRecord> sourceRecords,
    required bool includeDrafts,
  }) async {
    final filtered = sourceRecords.where((r) {
      if (r.projectId != projectId) return false;
      if (r.obra != obraFixa) return false;
      if (r.torre != torre) return false;
      if (r.fvsCodigo != fvsCodigo) return false;
      if (r.deleted) return false;
      if (!includeDrafts && r.isDraft) return false;
      return true;
    }).toList();

    filtered.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final fvsNome = filtered.isNotEmpty ? filtered.first.fvsNome : '';

    final matrix = MatrixReportBuilder.build(
      obra: obraFixa,
      torre: torre,
      fvsCodigo: fvsCodigo,
      fvsNome: fvsNome,
      source: filtered,
      responsavel: '',
    );

    final pdf = pw.Document();
    final localColumns = matrix.locais;

    const maxDataColumnsPerPage = 16;
    final columnChunks = _chunkList(localColumns, maxDataColumnsPerPage);

    if (matrix.rows.isEmpty || localColumns.isEmpty) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(18),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Relatório Matricial — Torre ${matrix.torre}',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text('Obra: ${matrix.obra}'),
                pw.Text(
                  'FVS: ${matrix.fvsCodigo}${matrix.fvsNome.isEmpty ? '' : ' - ${matrix.fvsNome}'}',
                ),
                pw.Text(
                  'Inspecionado por: ${matrix.rows.isNotEmpty ? matrix.rows.first.cellsByLocal.values.first.responsavel : ''}',
                ),
                pw.Text('Data: ${_formatDate(matrix.generatedAt)}'),
                pw.SizedBox(height: 12),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                  ),
                  child: pw.Text('Sem dados para montar a matriz desta FVS.'),
                ),
              ],
            );
          },
        ),
      );
    } else {
      final sheets = <List<List<String>>>[];
      for (var i = 0; i < columnChunks.length; i += 2) {
        final end = i + 2 < columnChunks.length ? i + 2 : columnChunks.length;
        sheets.add(columnChunks.sublist(i, end));
      }

      for (var pageIndex = 0; pageIndex < sheets.length; pageIndex++) {
        final sheetBlocks = sheets[pageIndex];
        final isFirstPage = pageIndex == 0;

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4.landscape,
            margin: const pw.EdgeInsets.all(18),
            build: (context) {
              final widgets = <pw.Widget>[];

              if (isFirstPage) {
                widgets.add(
                  pw.Text(
                    'Relatório Matricial — Torre ${matrix.torre}',
                    style: pw.TextStyle(
                      fontSize: 15,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                );
                widgets.add(pw.SizedBox(height: 2));
                widgets.add(pw.Text('Obra: ${matrix.obra}'));
                widgets.add(
                  pw.Text(
                    'FVS: ${matrix.fvsCodigo}${matrix.fvsNome.isEmpty ? '' : ' - ${matrix.fvsNome}'}',
                  ),
                );
                widgets.add(
                  pw.Text(
                    'Inspecionado por: ${matrix.rows.first.cellsByLocal.values.first.responsavel}',
                  ),
                );
                widgets.add(
                  pw.Text('Data: ${_formatDate(matrix.generatedAt)}'),
                );
                widgets.add(pw.SizedBox(height: 5));
                widgets.add(
                  pw.Text(
                    'Legenda: - não inspecionado | O aprovado | X reprovado | XO aprovado após correção',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                );
                widgets.add(pw.SizedBox(height: 7));
              } else {
                widgets.add(
                  pw.Text(
                    'Continuação — Torre ${matrix.torre} • FVS ${matrix.fvsCodigo}',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                );
                widgets.add(pw.SizedBox(height: 4));
              }

              for (
                var blockIndex = 0;
                blockIndex < sheetBlocks.length;
                blockIndex++
              ) {
                final localChunk = sheetBlocks[blockIndex];
                final headers = <String>['Item', ...localChunk];
                final data = matrix.rows.map((row) {
                  final line = <String>[row.item];
                  for (final local in localChunk) {
                    final cell = row.cellsByLocal[local];
                    line.add(_statusLabel(cell?.status ?? 'none'));
                  }
                  return line;
                }).toList();

                final widths = <int, pw.TableColumnWidth>{
                  0: const pw.FixedColumnWidth(200),
                };
                for (var i = 1; i <= localChunk.length; i++) {
                  widths[i] = const pw.FixedColumnWidth(35);
                }

                widgets.add(pw.SizedBox(height: 2));
                widgets.add(
                  pw.Container(
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(
                        color: PdfColors.grey500,
                        width: 0.4,
                      ),
                    ),
                    child: pw.TableHelper.fromTextArray(
                      headerDecoration: const pw.BoxDecoration(
                        color: PdfColors.grey300,
                      ),
                      headerStyle: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 8,
                      ),
                      cellStyle: const pw.TextStyle(fontSize: 8),
                      cellPadding: const pw.EdgeInsets.symmetric(
                        horizontal: 3,
                        vertical: 2,
                      ),
                      cellHeight: 16,
                      cellAlignment: pw.Alignment.center,
                      headerAlignment: pw.Alignment.center,
                      headers: headers,
                      data: data,
                      columnWidths: widths,
                      headerCount: 1,
                      border: pw.TableBorder(
                        left: const pw.BorderSide(
                          color: PdfColors.grey500,
                          width: 0.25,
                        ),
                        right: const pw.BorderSide(
                          color: PdfColors.grey500,
                          width: 0.25,
                        ),
                        top: const pw.BorderSide(
                          color: PdfColors.grey500,
                          width: 0.25,
                        ),
                        bottom: const pw.BorderSide(
                          color: PdfColors.grey500,
                          width: 0.25,
                        ),
                        horizontalInside: const pw.BorderSide(
                          color: PdfColors.grey400,
                          width: 0.2,
                        ),
                        verticalInside: const pw.BorderSide(
                          color: PdfColors.grey400,
                          width: 0.2,
                        ),
                      ),
                      cellAlignments: {0: pw.Alignment.centerLeft},
                    ),
                  ),
                );

                if (blockIndex == 0 && sheetBlocks.length > 1) {
                  widgets.add(pw.SizedBox(height: 6));
                  widgets.add(
                    pw.Container(height: 0.8, color: PdfColors.grey300),
                  );
                  widgets.add(pw.SizedBox(height: 6));
                }
              }

              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: widgets,
              );
            },
          ),
        );
      }
    }

    final directory = await getApplicationDocumentsDirectory();
    final dt = DateTime.now();
    final stamp =
        '${dt.year.toString().padLeft(4, '0')}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}_${dt.hour.toString().padLeft(2, '0')}${dt.minute.toString().padLeft(2, '0')}';
    final fileName = _sanitize(
      'Relatorio_Matricial_${obraFixa}_${torre}_${fvsCodigo}_$stamp.pdf',
    );
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  String _statusLabel(String status) {
    return _statusSymbolFromRaw(status);
  }

  String _statusSymbolFromRaw(String? rawStatus) {
    final status = _normalizeStatus(rawStatus);
    switch (status) {
      case 'ok':
        return 'O';
      case 'nok':
        return 'X';
      case 'okafterfix':
        return 'XO';
      case 'na':
      case 'pending':
      default:
        return '-';
    }
  }

  PdfColor _statusSymbolColor(String symbol) {
    switch (symbol) {
      case 'O':
        return _hex(0xFF166534);
      case 'X':
        return _hex(0xFF991B1B);
      case 'XO':
        return _hex(0xFF92400E);
      default:
        return _hex(0xFF555555);
    }
  }

  String _buildFileName(InspectionRecord record) {
    final dt = record.updatedAt;
    final stamp =
        '${dt.year.toString().padLeft(4, '0')}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}_${dt.hour.toString().padLeft(2, '0')}${dt.minute.toString().padLeft(2, '0')}';
    final raw =
        'Relatorio_${record.obra}_${record.torre}_${record.andar}_${record.apto}_${record.fvsCodigo}_${InspectionRecord.inspectionElementKey(record.inspectionElement)}_$stamp.pdf';
    return _sanitize(raw);
  }

  String _buildWebFriendlyFileName(InspectionRecord record) {
    final dt = DateTime.now();
    final stamp =
        '${dt.year.toString().padLeft(4, '0')}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}_${dt.hour.toString().padLeft(2, '0')}${dt.minute.toString().padLeft(2, '0')}';
    final raw = 'relatorio_${record.fvsCodigo}_$stamp.pdf';
    return _sanitize(raw).toLowerCase();
  }

  Future<File> _savePdfToDocuments({
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError(
        'Salvamento local em arquivo não é suportado na web. Use exportarPdf().',
      );
    }
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file;
  }

  String _sanitize(String value) {
    const from = 'áàãâäéèêëíìîïóòõôöúùûüçÁÀÃÂÄÉÈÊËÍÌÎÏÓÒÕÔÖÚÙÛÜÇ';
    const to = 'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC';

    var out = value;
    for (int i = 0; i < from.length; i++) {
      out = out.replaceAll(from[i], to[i]);
    }
    out = out.replaceAll(' ', '_');
    out = out.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '');
    out = out.replaceAll(RegExp(r'_+'), '_');
    return out;
  }

  String _stripNonPrintable(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      // Keep printable Basic Latin and Latin Extended (covers Portuguese)
      if ((rune >= 0x20 && rune <= 0x7E) || (rune >= 0xA0 && rune <= 0x2FF)) {
        buffer.writeCharCode(rune);
      } else if (rune == 0x09 || rune == 0x0A || rune == 0x0D) {
        buffer.write(' ');
      }
    }
    return buffer.toString().replaceAll(RegExp(r' +'), ' ').trim();
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateOnly(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  List<List<T>> _chunkList<T>(List<T> input, int chunkSize) {
    if (input.isEmpty) return <List<T>>[];
    final out = <List<T>>[];
    for (var i = 0; i < input.length; i += chunkSize) {
      final end = (i + chunkSize < input.length) ? i + chunkSize : input.length;
      out.add(input.sublist(i, end));
    }
    return out;
  }
}

class _FvsPdfPayload {
  final String obraNome;
  final String tower;
  final String location;
  final String fvsCode;
  final String fvsName;
  final String operationalSheetLabel;
  final String statusLabel;
  final DateTime inspectionDate;
  final String inspectorName;
  final List<InspectionItemResult> items;
  final List<_PdfPhotoEntry> photos;
  final bool openedNc;
  final String generalNotes;

  const _FvsPdfPayload({
    required this.obraNome,
    required this.tower,
    required this.location,
    required this.fvsCode,
    required this.fvsName,
    this.operationalSheetLabel = '',
    this.statusLabel = 'Sem status',
    required this.inspectionDate,
    required this.inspectorName,
    required this.items,
    required this.photos,
    required this.openedNc,
    required this.generalNotes,
  });
}

class _NcGroupedRow {
  final String itemDescricao;
  final String observacao;
  final String prazo;
  final String responsavel;
  final String local;

  _NcGroupedRow({
    required this.itemDescricao,
    required this.observacao,
    required this.prazo,
    required this.responsavel,
    required this.local,
  });
}

class _PdfPhotoEntry {
  final Uint8List bytes;
  final String caption;

  const _PdfPhotoEntry({required this.bytes, required this.caption});
}

class _FvsPdfMatrixData {
  const _FvsPdfMatrixData({required this.locations, required this.rows});

  final List<String> locations;
  final List<_FvsPdfMatrixRow> rows;
}

class _FvsPdfMatrixRow {
  const _FvsPdfMatrixRow({
    required this.description,
    required this.statusByLocation,
  });

  final String description;
  final Map<String, String> statusByLocation;
}
