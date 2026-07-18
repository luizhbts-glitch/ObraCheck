import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../models/diary_record.dart';
import '../utils/app_date_utils.dart';

class ProjectDataAnalysisScreen extends StatefulWidget {
  const ProjectDataAnalysisScreen({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  final String projectId;
  final String projectName;

  @override
  State<ProjectDataAnalysisScreen> createState() =>
      _ProjectDataAnalysisScreenState();
}

class _ProjectDataAnalysisScreenState extends State<ProjectDataAnalysisScreen> {
  final ImagePicker _imagePicker = ImagePicker();

  _ProjectScheduleConfig _scheduleConfig = const _ProjectScheduleConfig();
  List<_ProjectMonthlyPhoto> _monthlyPhotos = const [];

  String get _scheduleStorageKey =>
      'project_analysis_schedule_${widget.projectId}';
  String get _photosStorageKey => 'project_analysis_monthly_photos_${widget.projectId}';

  @override
  void initState() {
    super.initState();
    _loadStoredData();
  }

  Future<void> _loadStoredData() async {
    final prefs = Hive.box('prefs');
    final scheduleMapRaw = prefs.get(_scheduleStorageKey);
    final photosListRaw = prefs.get(_photosStorageKey);

    final schedule = scheduleMapRaw is Map
        ? _ProjectScheduleConfig.fromMap(
            Map<String, dynamic>.from(scheduleMapRaw),
          )
        : const _ProjectScheduleConfig();

    final photos = photosListRaw is List
        ? photosListRaw
            .whereType<Map>()
            .map((e) => _ProjectMonthlyPhoto.fromMap(Map<String, dynamic>.from(e)))
            .toList()
        : <_ProjectMonthlyPhoto>[];
    photos.sort((a, b) => a.date.compareTo(b.date));

    if (!mounted) return;
    setState(() {
      _scheduleConfig = schedule;
      _monthlyPhotos = photos;
    });
  }

  Future<void> _saveStoredData() async {
    final prefs = Hive.box('prefs');
    await prefs.put(_scheduleStorageKey, _scheduleConfig.toMap());
    await prefs.put(
      _photosStorageKey,
      _monthlyPhotos.map((e) => e.toMap()).toList(),
    );
  }

  Future<void> _configureSchedule() async {
    final contractController = TextEditingController(
      text: _scheduleConfig.contractDays > 0
          ? _scheduleConfig.contractDays.toString()
          : '',
    );
    DateTime? startDate = _scheduleConfig.startDate;
    DateTime? expectedEndDate = _scheduleConfig.expectedEndDate;
    String status = _scheduleConfig.status;

    Future<void> pickStart(StateSetter setDialogState) async {
      final picked = await showDatePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        initialDate: startDate ?? AppDateUtils.getTodayDate(),
      );
      if (picked == null) return;
      setDialogState(() => startDate = AppDateUtils.normalizeLocalDate(picked));
    }

    Future<void> pickEnd(StateSetter setDialogState) async {
      final picked = await showDatePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        initialDate: expectedEndDate ?? AppDateUtils.getTodayDate(),
      );
      if (picked == null) return;
      setDialogState(() => expectedEndDate = AppDateUtils.normalizeLocalDate(picked));
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Configurar prazo da obra'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: const InputDecoration(
                        labelText: 'Status da obra',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Em andamento',
                          child: Text('Em andamento'),
                        ),
                        DropdownMenuItem(
                          value: 'Concluída',
                          child: Text('Concluída'),
                        ),
                        DropdownMenuItem(
                          value: 'Paralisada',
                          child: Text('Paralisada'),
                        ),
                      ],
                      onChanged: (value) {
                        setDialogState(() => status = value ?? 'Em andamento');
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: contractController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Prazo contratual (dias)',
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => pickStart(setDialogState),
                      icon: const Icon(Icons.play_arrow_outlined),
                      label: Text(
                        startDate == null
                            ? 'Selecionar data de início'
                            : 'Início: ${AppDateUtils.formatDateBr(startDate!)}',
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => pickEnd(setDialogState),
                      icon: const Icon(Icons.flag_outlined),
                      label: Text(
                        expectedEndDate == null
                            ? 'Selecionar previsão de término'
                            : 'Previsão: ${AppDateUtils.formatDateBr(expectedEndDate!)}',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) {
      contractController.dispose();
      return;
    }

    final contractDays = int.tryParse(contractController.text.trim()) ?? 0;
    contractController.dispose();

    setState(() {
      _scheduleConfig = _ProjectScheduleConfig(
        status: status.trim().isEmpty ? 'Em andamento' : status.trim(),
        contractDays: contractDays,
        startDate: startDate,
        expectedEndDate: expectedEndDate,
      );
    });
    await _saveStoredData();
  }

  Future<void> _addMonthlyPhoto({required bool fromCamera}) async {
    final picked = await _imagePicker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
    );
    if (picked == null) return;
    if (!mounted) return;

    final pickedDate = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: AppDateUtils.getTodayDate(),
    );
    if (pickedDate == null) return;

    final normalizedDate = AppDateUtils.normalizeLocalDate(pickedDate);
    final id =
        'monthly_${widget.projectId}_${DateTime.now().microsecondsSinceEpoch}';

    _ProjectMonthlyPhoto newPhoto;
    if (kIsWeb) {
      final bytes = await picked.readAsBytes();
      final mime = picked.mimeType?.trim().isNotEmpty == true
          ? picked.mimeType!.trim()
          : 'image/jpeg';
      final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
      newPhoto = _ProjectMonthlyPhoto(
        id: id,
        date: normalizedDate,
        dataUrl: dataUrl,
      );
    } else {
      final appDir = await getApplicationDocumentsDirectory();
      final targetDir =
          Directory('${appDir.path}/project_analysis/${widget.projectId}');
      await targetDir.create(recursive: true);
      final filename =
          'monthly_${normalizedDate.year}${normalizedDate.month.toString().padLeft(2, '0')}${normalizedDate.day.toString().padLeft(2, '0')}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final targetPath = '${targetDir.path}/$filename';
      await File(picked.path).copy(targetPath);
      newPhoto = _ProjectMonthlyPhoto(
        id: id,
        date: normalizedDate,
        localPath: targetPath,
      );
    }

    setState(() {
      _monthlyPhotos = [..._monthlyPhotos, newPhoto]
        ..sort((a, b) => a.date.compareTo(b.date));
    });
    await _saveStoredData();
  }

  Future<void> _removeMonthlyPhoto(_ProjectMonthlyPhoto photo) async {
    if (!kIsWeb && photo.localPath.trim().isNotEmpty) {
      final file = File(photo.localPath);
      if (await file.exists()) {
        await file.delete();
      }
    }
    setState(() {
      _monthlyPhotos = _monthlyPhotos.where((e) => e.id != photo.id).toList();
    });
    await _saveStoredData();
  }

  _DiarySummary _buildDiarySummary(List<DiaryRecord> diaries) {
    final totalDias = diaries.length;
    final totalFrentes = diaries.fold<int>(
      0,
      (sum, diary) => sum + diary.serviceEntries.length,
    );
    final totalPessoas = diaries.fold<int>(
      0,
      (sum, diary) {
        final own = diary.ownLaborEntries.fold<int>(
          0,
          (acc, e) => acc + e.peopleCount,
        );
        final third = diary.serviceEntries.fold<int>(
          0,
          (acc, e) => acc + e.peopleCount,
        );
        return sum + own + third;
      },
    );

    return _DiarySummary(
      totalDias: totalDias,
      totalFrentes: totalFrentes,
      totalPessoas: totalPessoas,
      mediaPessoasPorDia: totalDias == 0 ? 0 : totalPessoas / totalDias,
      mediaFrentesPorDia: totalDias == 0 ? 0 : totalFrentes / totalDias,
    );
  }

  String _formatDecimal(num value) {
    final rounded = value.toStringAsFixed(1);
    if (rounded.endsWith('.0')) {
      return rounded.substring(0, rounded.length - 2);
    }
    return rounded;
  }

  String _monthLabel(DateTime date) {
    const months = [
      'Jan',
      'Fev',
      'Mar',
      'Abr',
      'Mai',
      'Jun',
      'Jul',
      'Ago',
      'Set',
      'Out',
      'Nov',
      'Dez',
    ];
    final month = months[(date.month - 1).clamp(0, 11)];
    return '$month/${date.year}';
  }

  Map<String, List<_ProjectMonthlyPhoto>> _groupPhotosByMonth() {
    final result = <String, List<_ProjectMonthlyPhoto>>{};
    for (final photo in _monthlyPhotos) {
      final key = _monthLabel(photo.date);
      result.putIfAbsent(key, () => []);
      result[key]!.add(photo);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final diariesBox = Hive.box<DiaryRecord>('diaries');
    final timeline = _ProjectTimelineMetrics.fromConfig(_scheduleConfig);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Análise de dados'),
        actions: [
          IconButton(
            tooltip: 'Configurar prazo',
            onPressed: _configureSchedule,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: ValueListenableBuilder<Box<DiaryRecord>>(
        valueListenable: diariesBox.listenable(),
        builder: (context, value, _) {
          final diaries = value.values
              .where(
                (d) =>
                    !d.deleted &&
                    d.projectId.trim() == widget.projectId.trim(),
              )
              .toList()
            ..sort((a, b) => a.date.compareTo(b.date));

          final summary = _buildDiarySummary(diaries);
          final photosByMonth = _groupPhotosByMonth();

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _SectionCard(
                title: 'Prazo da obra',
                trailing: Text(
                  _scheduleConfig.status,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(
                      value: timeline.progress,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MetricChip(
                          label: 'Prazo contratual',
                          value: '${timeline.totalDays} dias',
                        ),
                        _MetricChip(
                          label: 'Prazo decorrido',
                          value: '${timeline.elapsedDays} dias',
                        ),
                        _MetricChip(
                          label: 'Prazo restante',
                          value: '${timeline.remainingDays} dias',
                        ),
                        _MetricChip(
                          label: 'Início',
                          value: _scheduleConfig.startDate == null
                              ? '-'
                              : AppDateUtils.formatDateBr(
                                  _scheduleConfig.startDate!,
                                ),
                        ),
                        _MetricChip(
                          label: 'Previsão',
                          value: _scheduleConfig.expectedEndDate == null
                              ? '-'
                              : AppDateUtils.formatDateBr(
                                  _scheduleConfig.expectedEndDate!,
                                ),
                        ),
                        _MetricChip(
                          label: 'Progresso',
                          value:
                              '${(timeline.progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                        ),
                      ],
                    ),
                    if (!timeline.isConfigured) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Configure início, previsão e prazo contratual para cálculo completo.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _SectionCard(
                title: 'Resumo dos diários',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MetricChip(
                      label: 'Dias registrados',
                      value: '${summary.totalDias}',
                    ),
                    _MetricChip(
                      label: 'Total de frentes',
                      value: '${summary.totalFrentes}',
                    ),
                    _MetricChip(
                      label: 'Total de pessoas',
                      value: '${summary.totalPessoas}',
                    ),
                    _MetricChip(
                      label: 'Média pessoas/dia',
                      value: _formatDecimal(summary.mediaPessoasPorDia),
                    ),
                    _MetricChip(
                      label: 'Média frentes/dia',
                      value: _formatDecimal(summary.mediaFrentesPorDia),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _SectionCard(
                title: 'Evolução da obra',
                trailing: Wrap(
                  spacing: 6,
                  children: [
                    IconButton(
                      tooltip: 'Adicionar foto (câmera)',
                      onPressed: () => _addMonthlyPhoto(fromCamera: true),
                      icon: const Icon(Icons.photo_camera_outlined),
                    ),
                    IconButton(
                      tooltip: 'Adicionar foto (galeria)',
                      onPressed: () => _addMonthlyPhoto(fromCamera: false),
                      icon: const Icon(Icons.photo_library_outlined),
                    ),
                  ],
                ),
                child: _monthlyPhotos.isEmpty
                    ? const Text('Nenhuma foto mensal cadastrada.')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: photosByMonth.entries.map((entry) {
                          final month = entry.key;
                          final photos = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  month,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 140,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: photos.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(width: 8),
                                    itemBuilder: (context, index) {
                                      final photo = photos[index];
                                      return _MonthlyPhotoCard(
                                        photo: photo,
                                        onDelete: () => _removeMonthlyPhoto(photo),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProjectScheduleConfig {
  const _ProjectScheduleConfig({
    this.status = 'Em andamento',
    this.contractDays = 0,
    this.startDate,
    this.expectedEndDate,
  });

  final String status;
  final int contractDays;
  final DateTime? startDate;
  final DateTime? expectedEndDate;

  Map<String, dynamic> toMap() {
    return {
      'status': status,
      'contractDays': contractDays,
      'startDate': startDate?.toIso8601String(),
      'expectedEndDate': expectedEndDate?.toIso8601String(),
    };
  }

  factory _ProjectScheduleConfig.fromMap(Map<String, dynamic> map) {
    DateTime? parse(dynamic raw) {
      if (raw == null) return null;
      final parsed = DateTime.tryParse(raw.toString());
      if (parsed == null) return null;
      return AppDateUtils.normalizeLocalDate(parsed);
    }

    return _ProjectScheduleConfig(
      status: (map['status'] ?? 'Em andamento').toString(),
      contractDays: (map['contractDays'] is int)
          ? map['contractDays'] as int
          : int.tryParse('${map['contractDays']}') ?? 0,
      startDate: parse(map['startDate']),
      expectedEndDate: parse(map['expectedEndDate']),
    );
  }
}

class _ProjectTimelineMetrics {
  const _ProjectTimelineMetrics({
    required this.isConfigured,
    required this.totalDays,
    required this.elapsedDays,
    required this.remainingDays,
    required this.progress,
  });

  final bool isConfigured;
  final int totalDays;
  final int elapsedDays;
  final int remainingDays;
  final double progress;

  factory _ProjectTimelineMetrics.fromConfig(_ProjectScheduleConfig config) {
    if (config.startDate == null ||
        config.expectedEndDate == null ||
        config.contractDays <= 0) {
      return const _ProjectTimelineMetrics(
        isConfigured: false,
        totalDays: 0,
        elapsedDays: 0,
        remainingDays: 0,
        progress: 0,
      );
    }

    final today = AppDateUtils.getTodayDate();
    final total = config.contractDays;
    final rawElapsed = today.difference(config.startDate!).inDays;
    final elapsed = rawElapsed.clamp(0, total);
    final remaining = (total - elapsed).clamp(0, total);
    final progress = total == 0 ? 0.0 : (elapsed / total).toDouble();

    return _ProjectTimelineMetrics(
      isConfigured: true,
      totalDays: total,
      elapsedDays: elapsed,
      remainingDays: remaining,
      progress: progress,
    );
  }
}

class _DiarySummary {
  const _DiarySummary({
    required this.totalDias,
    required this.totalFrentes,
    required this.totalPessoas,
    required this.mediaPessoasPorDia,
    required this.mediaFrentesPorDia,
  });

  final int totalDias;
  final int totalFrentes;
  final int totalPessoas;
  final double mediaPessoasPorDia;
  final double mediaFrentesPorDia;
}

class _ProjectMonthlyPhoto {
  const _ProjectMonthlyPhoto({
    required this.id,
    required this.date,
    this.localPath = '',
    this.dataUrl = '',
  });

  final String id;
  final DateTime date;
  final String localPath;
  final String dataUrl;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'localPath': localPath,
      'dataUrl': dataUrl,
    };
  }

  factory _ProjectMonthlyPhoto.fromMap(Map<String, dynamic> map) {
    final parsedDate = DateTime.tryParse((map['date'] ?? '').toString()) ??
        AppDateUtils.getTodayDate();
    return _ProjectMonthlyPhoto(
      id: (map['id'] ?? '').toString(),
      date: AppDateUtils.normalizeLocalDate(parsedDate),
      localPath: (map['localPath'] ?? '').toString(),
      dataUrl: (map['dataUrl'] ?? '').toString(),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                trailing ?? const SizedBox.shrink(),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: scheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _MonthlyPhotoCard extends StatelessWidget {
  const _MonthlyPhotoCard({
    required this.photo,
    required this.onDelete,
  });

  final _ProjectMonthlyPhoto photo;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    Widget image;
    if (photo.dataUrl.trim().isNotEmpty) {
      image = Image.network(
        photo.dataUrl,
        fit: BoxFit.cover,
        width: 160,
        height: 90,
      );
    } else if (!kIsWeb && photo.localPath.trim().isNotEmpty) {
      image = Image.file(
        File(photo.localPath),
        fit: BoxFit.cover,
        width: 160,
        height: 90,
        errorBuilder: (_, error, stackTrace) => _missingImagePlaceholder(),
      );
    } else {
      image = _missingImagePlaceholder();
    }

    return Container(
      width: 170,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: image,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  AppDateUtils.formatDateBr(photo.date),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _missingImagePlaceholder() {
    return Container(
      width: 160,
      height: 90,
      color: Colors.black12,
      alignment: Alignment.center,
      child: const Icon(Icons.broken_image_outlined),
    );
  }
}
