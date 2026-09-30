// ignore_for_file: unused_element, unused_import, prefer_final_fields, unnecessary_import, curly_braces_in_flow_control_structures

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/arsen_structure.dart';
import '../data/fvs_catalog.dart';
import '../data/fvs_location_catalog.dart';
import '../models/inspection_record.dart';
import '../models/project_settings_record.dart';
import '../services/pdf_download_helper.dart';
import '../services/pdf_report_service.dart';
import '../services/project_context_service.dart';
import '../services/project_settings_service.dart';
import '../theme/app_colors.dart';
import '../utils/fvs_icon_formatter.dart';
import '../utils/project_scope.dart';
import '../utils/report_inspection_rules.dart';
import 'report_detail_screen.dart';
import 'select_location_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, this.initialFrom, this.initialTo});

  final DateTime? initialFrom;
  final DateTime? initialTo;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  static const String _withoutElementFilter = '__SEM_ELEMENTO__';

  Map<String, dynamic>? _selectedHistoryLocation;

  String? _torreSelecionada;
  int? _andarSelecionado;
  String? _localRefSelecionado;
  String? _fvsCodigoSelecionado;
  String? _inspectionElementSelecionado;
  int? _periodDays = 30;
  DateTime? _fromDate;
  DateTime? _toDate;
  late final ScrollController _filtersScrollController;
  bool _canScrollLeft = false;
  bool _canScrollRight = false;
  final PdfReportService _pdfService = PdfReportService();
  final ProjectContextService _projectContext = ProjectContextService.instance;
  final ProjectSettingsService _projectSettings =
      ProjectSettingsService.instance;

  bool _isGeneratingReportPdf = false;

  @override
  void initState() {
    super.initState();
    _fromDate = widget.initialFrom;
    _toDate = widget.initialTo;
    if (_fromDate != null && _toDate != null) {
      _periodDays = null;
    }
    _filtersScrollController = ScrollController()..addListener(_onFilterScroll);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _updateScrollIndicators(),
    );
  }

  @override
  void dispose() {
    _filtersScrollController.removeListener(_onFilterScroll);
    _filtersScrollController.dispose();
    super.dispose();
  }

  void _onFilterScroll() => _updateScrollIndicators();

  void _updateScrollIndicators() {
    if (!_filtersScrollController.hasClients) return;
    final pos = _filtersScrollController.position;
    final left = pos.pixels > 2;
    final right = pos.maxScrollExtent - pos.pixels > 2;
    if (left != _canScrollLeft || right != _canScrollRight) {
      if (mounted) {
        setState(() {
          _canScrollLeft = left;
          _canScrollRight = right;
        });
      }
    }
  }

  List<String> get _pdfScopeTowerOrder {
    final towers = ObraStructure.torres;
    if (towers.contains('Garagem')) return towers;
    return <String>['Garagem', ...towers];
  }

  String get _obraFixa => _projectContext.currentProjectNameSync;
  String get _currentProjectId => _projectContext.currentProjectIdSync;

  bool _statusMatches(InspectionRecord r) {
    return isInspectionEligibleForReport(r);
  }

  int _compareFvsCode(String a, String b) {
    final pa = a.split('.').map((e) => int.tryParse(e) ?? 999999).toList();
    final pb = b.split('.').map((e) => int.tryParse(e) ?? 999999).toList();
    final max = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < max; i++) {
      final va = i < pa.length ? pa[i] : -1;
      final vb = i < pb.length ? pb[i] : -1;
      if (va != vb) return va.compareTo(vb);
    }
    return a.toLowerCase().compareTo(b.toLowerCase());
  }

  String _recordLocalRef(InspectionRecord r) {
    final ref = r.localRef?.trim();
    if (ref != null && ref.isNotEmpty) return ref;
    return 'APTO_${r.apto}';
  }

  String _localLabelFromRef(String ref) {
    if (ref.startsWith('APTO_')) return 'Apto ${ref.substring(5)}';

    switch (ref) {
      case 'HALL':
        return 'Hall';
      case 'ESCADA':
        return 'Escada';
      case 'ELEVADOR':
        return 'Elevador';
      case 'COBERTURA':
      case 'ROOFTOP':
        return 'Rooftop';
      default:
        return ref;
    }
  }

  bool _matchesSelectedLocation(InspectionRecord r) {
    final selected = _selectedHistoryLocation;
    if (selected == null) return true;

    final selectedTorre = selected['torre']?.toString().trim();
    if (selectedTorre != null &&
        selectedTorre.isNotEmpty &&
        r.torre != selectedTorre) {
      return false;
    }

    final selectedLocalRef = selected['localRef']?.toString().trim();
    final selectedApto = selected['apto']?.toString().trim();
    final selectedAmbiente = selected['ambiente']?.toString().trim();

    final recordLocalRef = _recordLocalRef(r);
    if (selectedLocalRef != null && selectedLocalRef.isNotEmpty) {
      return recordLocalRef.toUpperCase() == selectedLocalRef.toUpperCase();
    }

    if (selectedApto != null && selectedApto.isNotEmpty) {
      return r.apto.trim().toUpperCase() == selectedApto.toUpperCase();
    }

    if (selectedAmbiente != null && selectedAmbiente.isNotEmpty) {
      final ambiente = selectedAmbiente.toLowerCase();
      final label = _localLabelFromRef(recordLocalRef).toLowerCase();
      return label.contains(ambiente) ||
          recordLocalRef.toLowerCase().contains(ambiente);
    }

    return true;
  }

  String _selectedLocationLabel() {
    final selected = _selectedHistoryLocation;
    if (selected == null) return 'Todos os locais';

    final torre = selected['torre']?.toString() ?? '';
    final localLabel = selected['localLabel']?.toString();
    final ambiente = selected['ambiente']?.toString();
    final apto = selected['apto']?.toString();
    final modulo = selected['modulo']?.toString();
    final nivel = selected['nivel']?.toString();

    if (localLabel != null && localLabel.trim().isNotEmpty)
      return '$torre • $localLabel';
    if (ambiente != null && ambiente.trim().isNotEmpty)
      return '$torre • $ambiente';
    if (apto != null && apto.trim().isNotEmpty) return '$torre • $apto';
    if ((modulo ?? '').isNotEmpty || (nivel ?? '').isNotEmpty) {
      return '$torre • ${modulo ?? ''} ${nivel ?? ''}'.trim();
    }
    return torre.isNotEmpty ? torre : 'Todos os locais';
  }

  Future<void> _pickHistoryLocation() async {
    final settings = ProjectSettingsService.instance.currentProjectSettingsSync;

    FvsTemplate? selectedTemplate;
    String locationContext = '';

    if (_fvsCodigoSelecionado != null && _fvsCodigoSelecionado!.isNotEmpty) {
      selectedTemplate = FvsCatalog.all
          .where((t) => t.codigo == _fvsCodigoSelecionado)
          .firstOrNull;
      if (selectedTemplate != null) {
        final profile = FvsLocationCatalog.profileForTemplate(selectedTemplate);
        locationContext = profile.defaultContextId;
        if (locationContext.isEmpty) {
          locationContext =
              settings?.fvsContextOverrides[selectedTemplate.codigo]
                  ?.toString() ??
              '';
        }
      }
    }

    final selected = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => SelectLocationScreen(
          title: 'Relatórios – Escolher local',
          autoOpenFvsOnMap: false,
          template: selectedTemplate,
          locationContext: locationContext,
        ),
      ),
    );

    if (!mounted || selected == null) return;
    setState(() {
      _selectedHistoryLocation = selected;
    });
  }

  List<InspectionRecord> _recordsForHistory(List<InspectionRecord> input) {
    final filtered =
        input.where((r) {
          if (!_statusMatches(r)) return false;
          if (_torreSelecionada != null && r.torre != _torreSelecionada)
            return false;
          if (_andarSelecionado != null && r.andar != _andarSelecionado)
            return false;
          if (_localRefSelecionado != null &&
              _recordLocalRef(r) != _localRefSelecionado) {
            return false;
          }
          if (_fvsCodigoSelecionado != null &&
              r.fvsCodigo != _fvsCodigoSelecionado) {
            return false;
          }
          if (_inspectionElementSelecionado != null) {
            final normalizedElement = r.normalizedInspectionElement;
            if (_inspectionElementSelecionado == _withoutElementFilter) {
              if (normalizedElement.isNotEmpty) return false;
            } else {
              if (normalizedElement != _inspectionElementSelecionado)
                return false;
            }
          }

          final eventAt = reportInspectionLastActionAt(r);
          if (_fromDate != null && _toDate != null) {
            final from = DateTime(
              _fromDate!.year,
              _fromDate!.month,
              _fromDate!.day,
            );
            final to = DateTime(
              _toDate!.year,
              _toDate!.month,
              _toDate!.day,
              23,
              59,
              59,
              999,
            );
            if (eventAt.isBefore(from) || eventAt.isAfter(to)) return false;
          } else if (_periodDays != null) {
            final threshold = DateTime.now().subtract(
              Duration(days: _periodDays!),
            );
            if (eventAt.isBefore(threshold)) return false;
          }

          return _matchesSelectedLocation(r);
        }).toList()..sort((a, b) {
          final aTime = reportInspectionLastActionAt(a);
          final bTime = reportInspectionLastActionAt(b);
          return bTime.compareTo(aTime);
        });

    return filtered;
  }

  String _statusPt(String status) {
    switch (status) {
      case 'draft':
        return 'Rascunho';
      case 'final':
      case 'finalized':
        return 'Finalizado';
      default:
        return status;
    }
  }

  _HistoryStatusVisual _historyStatus(InspectionRecord r) {
    final appColors = context.appColors;
    final ncOpen = reportInspectionNcOpenCount(r);
    switch (reportInspectionStatusKind(r)) {
      case ReportInspectionStatusKind.ncOpen:
        return _HistoryStatusVisual.ncOpen(ncOpen, appColors);
      case ReportInspectionStatusKind.ncCorrected:
        return _HistoryStatusVisual.ncCorrected(appColors);
      case ReportInspectionStatusKind.draft:
        return _HistoryStatusVisual.draft(appColors);
      case ReportInspectionStatusKind.finalized:
        return _HistoryStatusVisual.finalized(appColors);
      case ReportInspectionStatusKind.other:
        return _HistoryStatusVisual.other(appColors);
    }
  }

  void _ensureValidSelections({
    required List<String> torreOptions,
    required List<int> andarOptions,
    required List<String> localOptions,
    required List<_FvsOption> fvsOptions,
  }) {
    var changed = false;

    if (_torreSelecionada != null &&
        !torreOptions.contains(_torreSelecionada)) {
      _torreSelecionada = null;
      _andarSelecionado = null;
      _localRefSelecionado = null;
      _fvsCodigoSelecionado = null;
      _inspectionElementSelecionado = null;
      changed = true;
    }
    if (_andarSelecionado != null &&
        !andarOptions.contains(_andarSelecionado)) {
      _andarSelecionado = null;
      _localRefSelecionado = null;
      _fvsCodigoSelecionado = null;
      _inspectionElementSelecionado = null;
      changed = true;
    }
    if (_localRefSelecionado != null &&
        !localOptions.contains(_localRefSelecionado)) {
      _localRefSelecionado = null;
      _fvsCodigoSelecionado = null;
      _inspectionElementSelecionado = null;
      changed = true;
    }
    if (_fvsCodigoSelecionado != null &&
        !fvsOptions.any((f) => f.codigo == _fvsCodigoSelecionado)) {
      _fvsCodigoSelecionado = null;
      _inspectionElementSelecionado = null;
      changed = true;
    }

    if (changed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  String _periodLabel() {
    if (_periodDays == null) return 'Tudo';
    return 'Últimos $_periodDays'
        'd';
  }

  Future<T?> _openSelectionSheet<T>({
    required String title,
    required List<T> options,
    required String Function(T) label,
    required T? selected,
    bool includeAll = true,
  }) async {
    return showModalBottomSheet<T?>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filtered = options.where((o) {
              if (query.trim().isEmpty) return true;
              return label(o).toLowerCase().contains(query.toLowerCase());
            }).toList();

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.62,
                  child: Column(
                    children: [
                      ListTile(
                        title: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: TextField(
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'Buscar',
                          ),
                          onChanged: (v) => setSheetState(() => query = v),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView(
                          children: [
                            if (includeAll)
                              ListTile(
                                leading: Icon(
                                  selected == null
                                      ? Icons.check_circle
                                      : Icons.circle_outlined,
                                ),
                                title: const Text('Todos'),
                                onTap: () => Navigator.pop<T?>(context, null),
                              ),
                            ...filtered.map(
                              (o) => ListTile(
                                leading: Icon(
                                  selected == o
                                      ? Icons.check_circle
                                      : Icons.circle_outlined,
                                ),
                                title: Text(label(o)),
                                onTap: () => Navigator.pop<T?>(context, o),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openPeriodSheet() async {
    final selected = await _openSelectionSheet<int?>(
      title: 'Selecionar período',
      options: const [7, 30, 90],
      label: (v) => 'Últimos ${v}d',
      selected: _periodDays,
      includeAll: true,
    );
    if (!mounted) return;
    setState(() {
      _periodDays = selected;
      if (selected != null) {
        _fromDate = null;
        _toDate = null;
      }
    });
  }

  String _dateRangeLabel() {
    if (_fromDate == null || _toDate == null) return _periodLabel();
    String f(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    return '${f(_fromDate!)} a ${f(_toDate!)}';
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initialRange = (_fromDate != null && _toDate != null)
        ? DateTimeRange(start: _fromDate!, end: _toDate!)
        : DateTimeRange(start: now.subtract(const Duration(days: 6)), end: now);

    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: initialRange,
      helpText: 'Selecionar intervalo',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar',
    );
    if (range == null || !mounted) return;
    setState(() {
      _fromDate = range.start;
      _toDate = range.end;
      _periodDays = null;
    });
  }

  Widget _compactFilterChip({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      onPressed: onTap,
      avatar: const Icon(Icons.filter_alt_outlined, size: 16),
      label: Text('$label: $value'),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _statusLabelForExport(String status) {
    return _statusPt(status);
  }

  String _localLabelForRecord(InspectionRecord r) {
    final ref = _recordLocalRef(r);
    return _localLabelFromRef(ref);
  }

  String _xmlEscape(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  String _spreadsheetCell(String value) {
    return '<Cell><Data ss:Type="String">${_xmlEscape(value)}</Data></Cell>';
  }

  String _buildSpreadsheetXml(List<InspectionRecord> records) {
    final headers = <String>[
      'Data',
      'Obra',
      'Torre',
      'Andar',
      'Apartamento/Unidade',
      'Local',
      'Elemento',
      'FVS Código',
      'FVS Nome',
      'Status Relatório',
      'NC em aberto',
      'Qtd OK',
      'Qtd X',
      'Qtd XO',
      'Qtd Sem marcação',
      'Observações',
      'Responsável',
      'Cargo',
      'Empreiteiro (NC)',
      'ID Relatório',
    ];

    final rowHeader = '<Row>${headers.map(_spreadsheetCell).join()}</Row>';
    final dataRows = records.map((r) {
      var ok = 0;
      var nok = 0;
      var xo = 0;
      var none = 0;
      final notes = <String>[];
      for (final item in r.itens) {
        switch (item.status) {
          case 'ok':
            ok++;
            break;
          case 'nok':
            nok++;
            break;
          case 'okAfterFix':
            xo++;
            break;
          default:
            none++;
            break;
        }
        final obs = item.obs.trim();
        if (obs.isNotEmpty) {
          notes.add('Item ${item.index + 1}: $obs');
        }
      }

      final eventAt = reportInspectionLastActionAt(r);
      final values = <String>[
        _formatDate(eventAt),
        r.obra,
        r.torre,
        '${r.andar}',
        r.apto,
        _localLabelForRecord(r),
        r.normalizedInspectionElement,
        r.fvsCodigo,
        r.fvsNome,
        reportInspectionStatusLabel(r),
        nok > 0 ? 'Sim' : 'Não',
        '$ok',
        '$nok',
        '$xo',
        '$none',
        notes.join(' | '),
        (r.actionByName ?? '').trim(),
        (r.actionByCargo ?? '').trim(),
        (r.ncCompanyName ?? '').trim(),
        r.id,
      ];

      return '<Row>${values.map(_spreadsheetCell).join()}</Row>';
    }).join();

    return '''<?xml version="1.0"?>
<?mso-application progid="Excel.Sheet"?>
<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"
 xmlns:o="urn:schemas-microsoft-com:office:office"
 xmlns:x="urn:schemas-microsoft-com:office:excel"
 xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">
 <Worksheet ss:Name="Relatorios">
  <Table>
   $rowHeader
   $dataRows
  </Table>
 </Worksheet>
</Workbook>''';
  }

  Future<void> _exportExcelByCurrentPeriod(
    List<InspectionRecord> source,
  ) async {
    final records = _recordsForHistory(source);
    if (records.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nenhum relatório encontrado para o período selecionado.',
          ),
        ),
      );
      return;
    }

    try {
      final now = DateTime.now();
      final fileName =
          'relatorios_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}.xls';
      final xml = _buildSpreadsheetXml(records);

      if (kIsWeb) {
        downloadBytes(
          bytes: Uint8List.fromList(utf8.encode(xml)),
          fileName: fileName,
          mimeType: 'application/vnd.ms-excel',
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Excel gerado e baixado.')),
        );
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(xml, flush: true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Excel gerado: ${file.path.split('\\').last}')),
      );

      try {
        await Share.shareXFiles([
          XFile(file.path),
        ], text: 'Relatórios exportados por período');
      } catch (_) {
        await OpenFilex.open(file.path);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Falha ao gerar Excel: $e')));
    }
  }

  Future<void> _generateReportByCurrentFilters(
    List<InspectionRecord> source,
  ) async {
    if (_isGeneratingReportPdf) return;

    final scope = await _pickPdfScope();
    if (!mounted || scope == null) return;

    try {
      setState(() => _isGeneratingReportPdf = true);
      final result = await _pdfService.exportarRelatorioConsolidado(
        projectId: _currentProjectId,
        obraFixa: _obraFixa,
        torre: scope.torre,
        fvsCodigo: scope.fvsCodigo,
        fvsNomeOverride: scope.fvsNome,
        operationalSheetId: scope.operationalSheetId,
        operationalSheetLabel: scope.operationalSheetLabel,
        sourceRecords: source,
        includeDrafts: true,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Relatório gerado com sucesso.')),
      );

      if (!result.downloadedInBrowser && result.filePath != null) {
        try {
          await Share.shareXFiles([
            XFile(result.filePath!),
          ], text: 'Relatório gerado no Obra Check');
        } catch (_) {
          await OpenFilex.open(result.filePath!);
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Falha ao gerar relatório: $e')));
    } finally {
      if (mounted) setState(() => _isGeneratingReportPdf = false);
    }
  }

  /// Relatório individual em lote — pedido do usuário em 2026-09-30: hoje só
  /// dá pra gerar o consolidado (todas as unidades da torre juntas numa
  /// matriz) ou um individual avulso via tela de NC (e só se tiver NC). Esse
  /// fluxo deixa escolher torre + FVS e depois quantas unidades quiser
  /// (ex.: 1101, 1102, 1103), gerando um PDF só com uma página por unidade,
  /// tenha NC ou não.
  Future<void> _generateIndividualBatchReport(
    List<InspectionRecord> source,
  ) async {
    if (_isGeneratingReportPdf) return;

    final scope = await _pickPdfScope();
    if (!mounted || scope == null) return;

    final selectedSheetId = (scope.operationalSheetId ?? '').trim();
    final filtered = source.where((r) {
      if (r.projectId != _currentProjectId) return false;
      if (r.obra != _obraFixa) return false;
      if (r.torre != scope.torre) return false;
      if (r.fvsCodigo != scope.fvsCodigo) return false;
      if (selectedSheetId.isNotEmpty &&
          (r.operationalSheetId ?? '').trim() != selectedSheetId) {
        return false;
      }
      if (r.deleted) return false;
      return true;
    }).toList();

    final latestByUnit = <String, InspectionRecord>{};
    for (final r in filtered) {
      final key = _recordLocalRef(r);
      final current = latestByUnit[key];
      if (current == null || r.updatedAt.isAfter(current.updatedAt)) {
        latestByUnit[key] = r;
      }
    }

    if (latestByUnit.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhuma inspeção encontrada para essa torre/FVS.'),
        ),
      );
      return;
    }

    final units = latestByUnit.keys.toList()
      ..sort((a, b) {
        final an = int.tryParse(latestByUnit[a]!.apto.trim());
        final bn = int.tryParse(latestByUnit[b]!.apto.trim());
        if (an != null && bn != null) return an.compareTo(bn);
        if (an != null) return -1;
        if (bn != null) return 1;
        return a.compareTo(b);
      });

    final selectedUnits = await _pickMultipleUnits(units, latestByUnit);
    if (!mounted || selectedUnits == null || selectedUnits.isEmpty) return;

    try {
      setState(() => _isGeneratingReportPdf = true);
      final records = selectedUnits
          .map((u) => latestByUnit[u]!)
          .toList(growable: false);
      final result = await _pdfService.exportarRelatorioIndividualEmLote(
        records,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Relatório individual gerado (${records.length} unidade(s)).',
          ),
        ),
      );

      if (!result.downloadedInBrowser && result.filePath != null) {
        try {
          await Share.shareXFiles([
            XFile(result.filePath!),
          ], text: 'Relatório individual gerado no Obra Check');
        } catch (_) {
          await OpenFilex.open(result.filePath!);
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Falha ao gerar relatório: $e')));
    } finally {
      if (mounted) setState(() => _isGeneratingReportPdf = false);
    }
  }

  Future<List<String>?> _pickMultipleUnits(
    List<String> units,
    Map<String, InspectionRecord> latestByUnit,
  ) async {
    final selected = <String>{};
    return showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filtered = units.where((u) {
              if (query.trim().isEmpty) return true;
              final label = _localLabelFromRef(u);
              final q = query.toLowerCase();
              return label.toLowerCase().contains(q) ||
                  u.toLowerCase().contains(q);
            }).toList();
            final allSelected =
                filtered.isNotEmpty && filtered.every(selected.contains);

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.75,
                  child: Column(
                    children: [
                      ListTile(
                        title: const Text(
                          'Selecionar unidades',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${selected.length} selecionada(s) de ${units.length}',
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: TextField(
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'Buscar unidade',
                          ),
                          onChanged: (v) => setSheetState(() => query = v),
                        ),
                      ),
                      CheckboxListTile(
                        value: allSelected,
                        title: Text(
                          allSelected
                              ? 'Desmarcar todos'
                              : 'Selecionar todos',
                        ),
                        onChanged: (v) => setSheetState(() {
                          if (v == true) {
                            selected.addAll(filtered);
                          } else {
                            selected.removeAll(filtered);
                          }
                        }),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: ListView(
                          children: filtered.map((u) {
                            final record = latestByUnit[u]!;
                            final label = _localLabelFromRef(u);
                            return CheckboxListTile(
                              value: selected.contains(u),
                              title: Text(label),
                              subtitle: Text(
                                reportInspectionStatusLabel(record),
                              ),
                              onChanged: (v) => setSheetState(() {
                                if (v == true) {
                                  selected.add(u);
                                } else {
                                  selected.remove(u);
                                }
                              }),
                            );
                          }).toList(growable: false),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: selected.isEmpty
                                ? null
                                : () =>
                                      Navigator.pop(context, selected.toList()),
                            child: Text('Gerar (${selected.length})'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<_ReportPdfScope?> _pickPdfScope() async {
    final towers = _pdfScopeTowerOrder;
    final selectedTower = await _openSelectionSheet<String>(
      title: 'Selecionar área/torre do relatório',
      options: towers,
      label: (v) => v,
      selected: null,
      includeAll: false,
    );
    if (selectedTower == null) return null;

    final fvsOptions =
        FvsCatalog.all
            .map(
              (t) => _FvsOption(codigo: t.codigo.trim(), nome: t.nome.trim()),
            )
            .where((f) => f.codigo.isNotEmpty)
            .toList()
          ..sort((a, b) => _compareFvsCode(a.codigo, b.codigo));

    final selectedFvs = await _openSelectionSheet<_FvsOption>(
      title: 'Selecionar FVS do relatório',
      options: fvsOptions,
      label: (v) => v.nome.trim().isEmpty
          ? 'FVS ${v.codigo}'
          : 'FVS ${v.codigo} • ${v.nome.trim()}',
      selected: null,
      includeAll: false,
    );

    if (selectedFvs == null) return null;

    final operationalSheets = _projectSettings
        .activeOperationalSheetsForFvsSync(selectedFvs.codigo);
    String? selectedOperationalSheetId;
    String? selectedOperationalSheetLabel;
    if (operationalSheets.length == 1) {
      selectedOperationalSheetId = operationalSheets.first.id;
      selectedOperationalSheetLabel = operationalSheets.first.label;
    } else if (operationalSheets.length > 1) {
      final selectedSheet = await _openSelectionSheet<FvsOperationalSheetConfig>(
        title: 'Selecionar folha operacional (opcional)',
        options: operationalSheets,
        label: (v) => v.label.trim().isEmpty
            ? 'Folha sem nome'
            : '${v.label.trim()}${(v.tower ?? '').trim().isNotEmpty ? ' • ${(v.tower ?? '').trim()}' : ''}',
        selected: null,
        includeAll: true,
      );
      if (selectedSheet != null) {
        selectedOperationalSheetId = selectedSheet.id;
        selectedOperationalSheetLabel = selectedSheet.label;
      }
    }

    return _ReportPdfScope(
      torre: selectedTower,
      fvsCodigo: selectedFvs.codigo,
      fvsNome: selectedFvs.nome,
      operationalSheetId: selectedOperationalSheetId,
      operationalSheetLabel: selectedOperationalSheetLabel,
    );
  }

  String _draftKeyForRecord(InspectionRecord r) {
    final localRef = r.localRef?.trim().isNotEmpty == true
        ? r.localRef!.trim()
        : r.apto;
    final elementKey = InspectionRecord.inspectionElementKey(
      r.inspectionElement,
    );
    final operationalSheetKey = (r.operationalSheetId ?? '').trim();
    return buildInspectionDraftKey(
      projectId: r.projectId,
      obra: r.obra,
      torre: r.torre,
      andar: '${r.andar}',
      localRef: localRef,
      fvsCodigo: r.fvsCodigo,
      inspectionElement: elementKey,
      operationalSheetId: operationalSheetKey,
    );
  }

  String _legacyDraftKeyForRecord(InspectionRecord r) {
    final localRef = r.localRef?.trim().isNotEmpty == true
        ? r.localRef!.trim()
        : r.apto;
    return buildInspectionLegacyDraftKey(
      obra: r.obra,
      torre: r.torre,
      andar: '${r.andar}',
      localRef: localRef,
      fvsCodigo: r.fvsCodigo,
    );
  }

  Future<bool> _confirmAction({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
    return confirmed == true;
  }

  Future<void> _deleteSingleReport(InspectionRecord record) async {
    final ok = await _confirmAction(
      title: 'Excluir relatório',
      message:
          'Deseja excluir este relatório?\nEsta ação não pode ser desfeita.',
      confirmLabel: 'Excluir',
    );
    if (!ok) return;

    final box = Hive.box<InspectionRecord>('inspections');
    final prefs = Hive.box('prefs');
    final draftKey = _draftKeyForRecord(record);
    final legacyDraftKey = _legacyDraftKeyForRecord(record);

    final tombstone = record.copyWith(
      deleted: true,
      pendingSync: true,
      deletedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await box.put(record.id, tombstone);
    await prefs.put('inspection_synced_${record.id}', false);

    final stored = prefs.get(draftKey);
    if (stored == record.id) {
      await prefs.delete(draftKey);
    }
    final legacyStored = prefs.get(legacyDraftKey);
    if (legacyStored == record.id) {
      await prefs.delete(legacyDraftKey);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Relatório excluído.')));
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<InspectionRecord>('inspections');

    return Scaffold(
      appBar: AppBar(title: const Text('Relatórios')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ValueListenableBuilder<Box<InspectionRecord>>(
          valueListenable: box.listenable(),
          builder: (context, value, _) {
            final all = value.values.where((r) => !r.deleted).toList();
            final currentProjectId = _projectContext.currentProjectIdSync;
            all
              ..clear()
              ..addAll(
                filterRecordsByProjectScope(
                  value.values.where((r) => !r.deleted),
                  currentProjectId: currentProjectId,
                  projectId: (r) => r.projectId,
                  obra: (r) => r.obra,
                ),
              );
            final history = _recordsForHistory(all);

            final torreOptions =
                all
                    .map((r) => r.torre)
                    .where((t) => t.trim().isNotEmpty)
                    .toSet()
                    .toList()
                  ..sort();

            final allByTorre = _torreSelecionada == null
                ? all
                : all.where((r) => r.torre == _torreSelecionada).toList();

            final andarOptions =
                allByTorre
                    .map((r) => r.andar)
                    .where((a) => a > 0)
                    .toSet()
                    .toList()
                  ..sort();

            final allByAndar = _andarSelecionado == null
                ? allByTorre
                : allByTorre
                      .where((r) => r.andar == _andarSelecionado)
                      .toList();

            final localOptions =
                allByAndar.map(_recordLocalRef).toSet().toList()..sort();

            final fvsOptions =
                allByAndar
                    .map(
                      (r) => _FvsOption(codigo: r.fvsCodigo, nome: r.fvsNome),
                    )
                    .fold<Map<String, _FvsOption>>({}, (acc, f) {
                      acc[f.codigo] ??= f;
                      return acc;
                    })
                    .values
                    .toList()
                  ..sort((a, b) => _compareFvsCode(a.codigo, b.codigo));

            final inspectionElementOptions =
                allByAndar
                    .map((r) => r.normalizedInspectionElement)
                    .toSet()
                    .toList()
                  ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
            final hasLegacyWithoutElement = allByAndar.any(
              (r) => r.normalizedInspectionElement.isEmpty,
            );

            _ensureValidSelections(
              torreOptions: torreOptions,
              andarOptions: andarOptions,
              localOptions: localOptions,
              fvsOptions: fvsOptions,
            );

            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickHistoryLocation,
                        icon: const Icon(Icons.place_outlined),
                        label: const Text('Selecionar local'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_selectedHistoryLocation != null)
                      IconButton(
                        tooltip: 'Limpar seleção',
                        onPressed: () =>
                            setState(() => _selectedHistoryLocation = null),
                        icon: const Icon(Icons.close),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  controller: _filtersScrollController,
                  child: Row(
                    children: [
                      _compactFilterChip(
                        label: 'Torre',
                        value: _torreSelecionada ?? 'Todas',
                        onTap: () async {
                          final selected = await _openSelectionSheet<String>(
                            title: 'Selecionar torre',
                            options: torreOptions,
                            label: (v) => v,
                            selected: _torreSelecionada,
                            includeAll: true,
                          );
                          if (!mounted) return;
                          setState(() {
                            _torreSelecionada = selected;
                            _andarSelecionado = null;
                            _localRefSelecionado = null;
                            _fvsCodigoSelecionado = null;
                            _inspectionElementSelecionado = null;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      _compactFilterChip(
                        label: 'Andar',
                        value: _andarSelecionado == null
                            ? 'Todos'
                            : '$_andarSelecionadoº',
                        onTap: () async {
                          final selected = await _openSelectionSheet<int>(
                            title: 'Selecionar andar',
                            options: andarOptions,
                            label: (v) => '$vº andar',
                            selected: _andarSelecionado,
                            includeAll: true,
                          );
                          if (!mounted) return;
                          setState(() {
                            _andarSelecionado = selected;
                            _localRefSelecionado = null;
                            _fvsCodigoSelecionado = null;
                            _inspectionElementSelecionado = null;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      _compactFilterChip(
                        label: 'Local',
                        value: _localRefSelecionado == null
                            ? 'Todos'
                            : _localLabelFromRef(_localRefSelecionado!),
                        onTap: () async {
                          final selected = await _openSelectionSheet<String>(
                            title: 'Selecionar local',
                            options: localOptions,
                            label: _localLabelFromRef,
                            selected: _localRefSelecionado,
                            includeAll: true,
                          );
                          if (!mounted) return;
                          setState(() {
                            _localRefSelecionado = selected;
                            _fvsCodigoSelecionado = null;
                            _inspectionElementSelecionado = null;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      _compactFilterChip(
                        label: 'Elemento',
                        value: _inspectionElementSelecionado == null
                            ? 'Todos'
                            : _inspectionElementSelecionado ==
                                  _withoutElementFilter
                            ? 'Sem elemento'
                            : _inspectionElementSelecionado!,
                        onTap: () async {
                          final options = <String>[
                            if (hasLegacyWithoutElement) _withoutElementFilter,
                            ...inspectionElementOptions.where(
                              (e) => e.isNotEmpty,
                            ),
                          ];
                          final selected = await _openSelectionSheet<String>(
                            title: 'Selecionar elemento',
                            options: options,
                            label: (v) =>
                                v == _withoutElementFilter ? 'Sem elemento' : v,
                            selected: _inspectionElementSelecionado,
                            includeAll: true,
                          );
                          if (!mounted) return;
                          setState(() {
                            _inspectionElementSelecionado = selected;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      _compactFilterChip(
                        label: 'Data',
                        value: _dateRangeLabel(),
                        onTap: () async => await _pickDateRange(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _selectedLocationLabel(),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async =>
                            await _exportExcelByCurrentPeriod(all),
                        icon: const Icon(Icons.table_view_outlined),
                        label: const Text('Gerar Excel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isGeneratingReportPdf
                            ? null
                            : () => _generateReportByCurrentFilters(all),
                        icon: _isGeneratingReportPdf
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.picture_as_pdf),
                        label: Text(
                          _isGeneratingReportPdf
                              ? 'Gerando...'
                              : 'Gerar Relatório',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isGeneratingReportPdf
                        ? null
                        : () => _generateIndividualBatchReport(all),
                    icon: const Icon(Icons.checklist_outlined),
                    label: const Text('Individual (várias unidades)'),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: history.isEmpty
                      ? const Center(
                          child: Text(
                            'Nenhum histórico encontrado para o local informado.',
                          ),
                        )
                      : ListView.separated(
                          itemCount: history.length,
                          separatorBuilder: (_, index) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final r = history[i];
                            final statusVisual = _historyStatus(r);
                            final localRef = _recordLocalRef(r);
                            final localLabel = _localLabelFromRef(localRef);
                            final elementLabel = r.normalizedInspectionElement;
                            final actionType =
                                r.actionType ??
                                InspectionRecord.actionTypeFromStatus(r.status);
                            final actionByName =
                                (r.actionByName?.trim().isNotEmpty == true)
                                ? r.actionByName!.trim()
                                : 'Usuário não identificado';
                            final hasSavedBy =
                                r.actionByName?.trim().isNotEmpty == true;
                            final actionByCargo =
                                (r.actionByCargo?.trim().isNotEmpty == true)
                                ? r.actionByCargo!.trim()
                                : 'Cargo não informado';
                            final actionTime = reportInspectionLastActionAt(r);

                            return Card(
                              color: statusVisual.lightColor,
                              child: ListTile(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          ReportDetailScreen(record: r),
                                    ),
                                  );
                                },
                                title: Text(
                                  elementLabel.isNotEmpty
                                      ? 'Local $localLabel • $elementLabel'
                                      : 'Local $localLabel',
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${FvsIconFormatter.getFvsIcon(r.fvsNome)} '
                                      '${r.fvsNome.trim().isNotEmpty ? r.fvsNome.trim() : 'FVS ${r.fvsCodigo}'}',
                                    ),
                                    if (elementLabel.isNotEmpty)
                                      Text('Elemento: $elementLabel'),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: statusVisual.color
                                                .withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            statusVisual.label,
                                            style: TextStyle(
                                              color: statusVisual.color,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                        if (statusVisual.ncCount > 0) ...[
                                          const SizedBox(width: 8),
                                          Text(
                                            '${statusVisual.ncCount} NC',
                                            style: TextStyle(
                                              color: Colors.red.shade700,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${actionType[0].toUpperCase()}${actionType.substring(1)} por $actionByName',
                                    ),
                                    Text(actionByCargo),
                                    Text(_formatDate(actionTime)),
                                  ],
                                ),
                                trailing: PopupMenuButton<String>(
                                  tooltip: 'Ações',
                                  onSelected: (value) async {
                                    if (value == 'delete') {
                                      await _deleteSingleReport(r);
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem<String>(
                                      value: 'delete',
                                      child: ListTile(
                                        leading: Icon(
                                          Icons.delete_outline,
                                          color: Colors.red,
                                        ),
                                        title: Text('Excluir relatório'),
                                      ),
                                    ),
                                  ],
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.more_vert),
                                      if (hasSavedBy)
                                        SizedBox(
                                          width: 74,
                                          child: Text(
                                            r.actionByName!.trim(),
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.black54,
                                              fontWeight: FontWeight.w700,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FvsOption {
  final String codigo;
  final String nome;

  _FvsOption({required this.codigo, required this.nome});
}

class _ReportPdfScope {
  final String torre;
  final String fvsCodigo;
  final String fvsNome;
  final String? operationalSheetId;
  final String? operationalSheetLabel;

  _ReportPdfScope({
    required this.torre,
    required this.fvsCodigo,
    required this.fvsNome,
    this.operationalSheetId,
    this.operationalSheetLabel,
  });
}

class _HistoryStatusVisual {
  final String label;
  final Color color;
  final Color lightColor;
  final int ncCount;

  const _HistoryStatusVisual({
    required this.label,
    required this.color,
    required this.lightColor,
    this.ncCount = 0,
  });

  factory _HistoryStatusVisual.other(AppColors colors) {
    return _HistoryStatusVisual(
      label: 'Sem status',
      color: colors.cardBackgroundText,
      lightColor: colors.cardBackground,
      ncCount: 0,
    );
  }

  factory _HistoryStatusVisual.draft(AppColors colors) {
    return _HistoryStatusVisual(
      label: 'Rascunho',
      color: colors.cardNCAbertaText,
      lightColor: colors.cardNCAberta,
      ncCount: 0,
    );
  }

  factory _HistoryStatusVisual.finalized(AppColors colors) {
    return _HistoryStatusVisual(
      label: 'Finalizado',
      color: colors.cardSemNCText,
      lightColor: colors.cardSemNC,
      ncCount: 0,
    );
  }

  factory _HistoryStatusVisual.ncOpen(int count, AppColors colors) {
    return _HistoryStatusVisual(
      label: 'NC aberta',
      color: colors.danger,
      lightColor: colors.cardNCAberta,
      ncCount: count,
    );
  }

  factory _HistoryStatusVisual.ncCorrected(AppColors colors) {
    return _HistoryStatusVisual(
      label: 'NC corrigida',
      color: colors.warning,
      lightColor: colors.warning.withValues(alpha: 0.18),
      ncCount: 0,
    );
  }
}
