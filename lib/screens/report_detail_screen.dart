import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../data/fvs_catalog.dart';
import '../models/inspection_record.dart';
import '../services/photo_service.dart';
import '../services/pdf_report_service.dart';
import '../theme/app_colors.dart';
import '../utils/report_inspection_rules.dart';
import '../utils/fvs_icon_formatter.dart';
import '../widgets/inspection_photo_image.dart';
import 'inspection_screen.dart';

class ReportDetailScreen extends StatefulWidget {
  const ReportDetailScreen({
    super.key,
    required this.record,
  });

  final InspectionRecord record;

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  final PdfReportService _pdfService = PdfReportService();
  bool _isGenerating = false;

  _DetailStatusVisual _detailStatus(BuildContext context, InspectionRecord record) {
    final appColors = context.appColors;
    switch (reportInspectionStatusKind(record)) {
      case ReportInspectionStatusKind.ncOpen:
        return _DetailStatusVisual(
          label: 'NC aberta',
          color: appColors.fvsNokForeground,
          lightColor: appColors.fvsNokContainer,
        );
      case ReportInspectionStatusKind.ncCorrected:
        return _DetailStatusVisual(
          label: 'NC corrigida',
          color: appColors.fvsXoForeground,
          lightColor: appColors.fvsXoContainer,
        );
      case ReportInspectionStatusKind.draft:
        return _DetailStatusVisual(
          label: 'Rascunho',
          color: appColors.fvsNoneForeground,
          lightColor: appColors.fvsNoneContainer,
        );
      case ReportInspectionStatusKind.finalized:
        return _DetailStatusVisual(
          label: 'Finalizado',
          color: appColors.fvsOkForeground,
          lightColor: appColors.fvsOkContainer,
        );
      case ReportInspectionStatusKind.other:
        return _DetailStatusVisual(
          label: 'Sem status',
          color: appColors.fvsNoneForeground,
          lightColor: appColors.fvsNoneContainer,
        );
    }
  }

  String? _savedByName(InspectionRecord record) {
    final actionByName = record.actionByName?.trim();
    if (actionByName != null && actionByName.isNotEmpty) return actionByName;

    final uid = record.actionByUid?.trim();
    if (uid != null && uid.isNotEmpty) {
      final shortUid = uid.length > 8 ? uid.substring(0, 8) : uid;
      return 'UID $shortUid';
    }

    return null;
  }

  String? _savedByCargo(InspectionRecord record) {
    final actionByCargo = record.actionByCargo?.trim();
    if (actionByCargo != null && actionByCargo.isNotEmpty) return actionByCargo;
    return null;
  }

  String? _ncCompanyForItem(InspectionRecord record, InspectionItemResult item) {
    final itemName = item.ncCompanyName?.trim();
    if (itemName != null && itemName.isNotEmpty) return itemName;
    final recordName = record.ncCompanyName?.trim();
    if (recordName != null && recordName.isNotEmpty) return recordName;
    return null;
  }

  String _resolveLocalLabel(InspectionRecord record) {
    final ref = record.localRef?.trim();
    if (ref == null || ref.isEmpty) return record.apto;
    if (ref.startsWith('APTO_')) return ref.substring(5);
    if (ref.startsWith('STRUCT_')) return ref.substring(7);
    if (ref.startsWith('FACADE_')) return ref.substring(7);
    if (ref.startsWith('SECTOR_')) return ref.substring(7);
    if (ref.startsWith('FREE_')) return ref.substring(5);
    return record.apto;
  }

  Future<void> _generatePdfConsolidado() async {
    if (_isGenerating) return;
    if (!mounted) return;
    setState(() => _isGenerating = true);
    try {
      final result = await _pdfService.exportarPdfConsolidadoIndividual(widget.record);
      if (!mounted) return;
      final msg = result.downloadedInBrowser
          ? 'PDF baixado: ${result.fileName}'
          : 'PDF gerado: ${result.fileName}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao gerar PDF: $e')),
      );
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _openInspection() {
    final record = widget.record;
    final matches = FvsCatalog.all.where((t) => t.codigo == record.fvsCodigo);
    if (matches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('FVS não encontrada no catálogo.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InspectionScreen(
          location: {
            'obra': record.obra,
            'torre': record.torre,
            'andar': record.andar,
            'apto': record.apto,
            if ((record.localRef ?? '').trim().isNotEmpty) 'localRef': record.localRef,
            'element': record.inspectionElement ?? '',
            'inspectionElement': record.inspectionElement ?? '',
            'operationalSheetId': record.operationalSheetId ?? '',
            'operationalSheetLabel': record.operationalSheetLabel ?? '',
          },
          template: matches.first,
          inspectionId: record.id,
        ),
      ),
    );
  }



  String _statusLabel(String status) {
    switch (status) {
      case 'ok':
        return 'O';
      case 'nok':
        return 'X';
      case 'okAfterFix':
        return 'XO (corrigido)';
      default:
        return '-';
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  List<InspectionPhotoData> _itemPhotos(
    InspectionItemResult item, {
    required String inspectionId,
  }) {
    if (item.photos.isNotEmpty) {
      for (var photoIndex = 0; photoIndex < item.photos.length; photoIndex++) {
        final photo = item.photos[photoIndex];
        debugPrint(
          '[PHOTO][WEB][DEBUG] inspectionId=$inspectionId itemIndex=${item.index} photoIndex=$photoIndex source=photos '
          'photoUrl="${photo.photoUrl}" '
          'photoUrlType=${PhotoService.instance.classifyPhotoValue(photo.photoUrl)} '
          'localPath="${photo.localPath}" '
          'localPathType=${PhotoService.instance.classifyPhotoValue(photo.localPath)} '
          'storagePath="${photo.storagePath}" '
          'pendingSync=${photo.pendingSync} syncError="${photo.syncError ?? ''}"',
        );
      }
      return item.photos;
    }

    final legacyMapped = item.photoPaths
        .where((url) => url.trim().isNotEmpty)
        .map(
          (url) {
            final raw = url.trim();
            final isRemote = PhotoService.instance.isRemoteUrl(raw);
            final isDataUrl = PhotoService.instance.isDataUrl(raw);
            return InspectionPhotoData(
              photoUrl: (isRemote || isDataUrl) ? raw : '',
              storagePath: isRemote
                  ? (PhotoService.instance.extractStoragePathFromUrl(raw) ?? '')
                  : '',
              localPath: (isRemote || isDataUrl) ? '' : raw,
              pendingSync: !(isRemote || isDataUrl),
              syncError: null,
            );
          },
        )
        .toList();

    if (legacyMapped.isNotEmpty) {
      for (var photoIndex = 0; photoIndex < legacyMapped.length; photoIndex++) {
        final photo = legacyMapped[photoIndex];
        debugPrint(
          '[PHOTO][WEB][DEBUG] inspectionId=$inspectionId itemIndex=${item.index} photoIndex=$photoIndex source=photoPaths-legacy '
          'raw="${photo.photoUrl}" storagePath="${photo.storagePath}"',
        );
      }
    }

    return legacyMapped;
  }

  Widget _buildPhotoWidget(
    InspectionPhotoData photo, {
    required String inspectionId,
    required int itemIndex,
    required int photoIndex,
    double? width,
    double? height,
    int? cacheWidth,
    BoxFit fit = BoxFit.cover,
  }) {
    debugPrint(
      '[PHOTO][WEB][DEBUG] inspectionId=$inspectionId itemIndex=$itemIndex photoIndex=$photoIndex '
      'platform=${kIsWeb ? 'web' : 'mobile'} '
      'photoUrl="${photo.photoUrl}" '
      'storagePath="${photo.storagePath}" '
      'localPath="${photo.localPath}" '
      'photoUrlType=${PhotoService.instance.classifyPhotoValue(photo.photoUrl)} '
      'localPathType=${PhotoService.instance.classifyPhotoValue(photo.localPath)} '
      'pendingSync=${photo.pendingSync} syncError="${photo.syncError ?? ''}"',
    );

    final trace = 'inspectionId=$inspectionId itemIndex=$itemIndex photoIndex=$photoIndex';

    return InspectionPhotoImage(
      photo: photo,
      width: width,
      height: height,
      fit: fit,
      cacheWidth: cacheWidth,
      logContext: '[PHOTO][WEB][RESOLVE]',
      debugTrace: trace,
      placeholderText: 'Imagem indisponível no navegador',
    );
  }

  Future<void> _showPhotoDialog(
    InspectionPhotoData photo, {
    required String inspectionId,
    required int itemIndex,
    required int photoIndex,
  }) async {
    if (!mounted) return;

    final canPreview = PhotoService.instance.canRenderPhotoOnCurrentPlatform(photo);
    debugPrint(
      '[PHOTO][WEB][DEBUG] inspectionId=$inspectionId itemIndex=$itemIndex photoIndex=$photoIndex '
      'preview.canRender=$canPreview photoUrl="${photo.photoUrl}" storagePath="${photo.storagePath}" '
      'localPath="${photo.localPath}" pendingSync=${photo.pendingSync} syncError="${photo.syncError ?? ''}"',
    );
    if (!canPreview) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Imagem indisponível no navegador')),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(20),
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: AspectRatio(
              aspectRatio: 1,
              child: _buildPhotoWidget(
                photo,
                inspectionId: inspectionId,
                itemIndex: itemIndex,
                photoIndex: photoIndex,
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final record = Hive.box<InspectionRecord>('inspections').get(widget.record.id) ?? widget.record;
    final statusVisual = _detailStatus(context, record);
    final savedByName = _savedByName(record);
    final savedByCargo = _savedByCargo(record);
    final localLabel = _resolveLocalLabel(record);
    final elementLabel = record.normalizedInspectionElement;
    final ncCompanyName = record.ncCompanyName?.trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhe do Relatório'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            title: 'Resumo da inspeção',
            backgroundColor: statusVisual.lightColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${FvsIconFormatter.getFvsIcon(record.fvsNome)} '
                        '${record.fvsNome.trim().isNotEmpty ? record.fvsNome.trim() : 'FVS ${record.fvsCodigo}'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusVisual.color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
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
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoPill(label: 'Obra', value: record.obra),
                    _InfoPill(label: 'Torre', value: record.torre),
                    _InfoPill(label: 'Andar', value: '${record.andar}º'),
                    _InfoPill(label: 'Local', value: localLabel),
                    if (elementLabel.isNotEmpty)
                      _InfoPill(label: 'Elemento', value: elementLabel),
                    if (ncCompanyName != null && ncCompanyName.isNotEmpty)
                      _InfoPill(label: 'Empreiteiro NC', value: ncCompanyName),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Criado em ${_formatDate(record.createdAt)}'),
                Text('Atualizado em ${_formatDate(record.updatedAt)}'),
                if (savedByName != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Salvo por: $savedByName',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (savedByCargo != null)
                    Text(
                      'Cargo: $savedByCargo',
                      style: const TextStyle(color: Colors.black54),
                    ),
],
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Itens',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var itemPos = 0; itemPos < record.itens.length; itemPos++)
                  Builder(builder: (_) {
                    final item = record.itens[itemPos];
                    final itemPhotos = _itemPhotos(item, inspectionId: record.id);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${item.index + 1}. ${item.descricao}',
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              const Text(
                                'Status:',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  color: _statusColor(item.status).container,
                                ),
                                child: Text(
                                  _statusLabel(item.status),
                                  style: TextStyle(
                                    color: _statusColor(item.status).foreground,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 10,
                            runSpacing: 6,
                            children: [
                              if (item.measuredValue != null)
                                Text(
                                  'Medição: ${item.measuredValue} ${item.measuredUnit ?? ''}'.trim(),
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              if ((item.technicalNote ?? '').trim().isNotEmpty)
                                Text(
                                  'Nota técnica: ${(item.technicalNote ?? '').trim()}',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              Text(
                                'Fotos: ${itemPhotos.length}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          if (item.obs.trim().isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.black.withValues(alpha: 0.03),
                                border: Border.all(color: Colors.black12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.status == 'okAfterFix' ? 'Correção' : 'Observação',
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(item.obs.trim()),
                                ],
                              ),
                            ),
                          if (item.status == 'nok') ...[
                            const SizedBox(height: 8),
                            Text(
                              'Empreiteiro responsável: ${_ncCompanyForItem(record, item) ?? 'Não informado'}',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          if (itemPhotos.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            if (itemPhotos.any((photo) => !PhotoService.instance.hasOnlineUrl(photo)))
                              Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.cloud_off_outlined, size: 16, color: Colors.black54),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Foto ainda não sincronizada para Web',
                                        style: TextStyle(
                                          color: Colors.black87,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: itemPhotos
                                  .asMap()
                                  .entries
                                  .map(
                                    (entry) {
                                      final photo = entry.value;
                                      final photoIndex = entry.key;
                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          InkWell(
                                            onTap: () async => await _showPhotoDialog(
                                              photo,
                                              inspectionId: record.id,
                                              itemIndex: item.index,
                                              photoIndex: photoIndex,
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: _buildPhotoWidget(
                                                photo,
                                                inspectionId: record.id,
                                                itemIndex: item.index,
                                                photoIndex: photoIndex,
                                                width: 120,
                                                height: 120,
                                                cacheWidth: 360,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ).toList(),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _openInspection,
                  icon: const Icon(Icons.assignment_outlined),
                  label: const Text('Abrir na FVS'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isGenerating ? null : _generatePdfConsolidado,
                  icon: _isGenerating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(_isGenerating ? 'Gerando...' : 'Gerar PDF'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.backgroundColor,
  });

  final String title;
  final Widget child;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor ?? theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _DetailStatusVisual {
  final String label;
  final Color color;
  final Color lightColor;

  const _DetailStatusVisual({
    required this.label,
    required this.color,
    required this.lightColor,
  });
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: theme.cardColor,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}

({Color container, Color foreground, Color border}) _statusColor(String status) {
  switch (status) {
    case 'ok':
      return (container: const Color(0xFFEAF7EC), foreground: const Color(0xFF2E7D32), border: const Color(0xFF9FD2A6));
    case 'nok':
      return (container: const Color(0xFFFFEBEE), foreground: const Color(0xFFC62828), border: const Color(0xFFE5A6A6));
    case 'okAfterFix':
      return (container: const Color(0xFFFFF4E0), foreground: const Color(0xFFB26A00), border: const Color(0xFFE8C89A));
    default:
      return (container: const Color(0xFFF1F1F1), foreground: const Color(0xFF757575), border: const Color(0xFFD0D0D0));
  }
}

