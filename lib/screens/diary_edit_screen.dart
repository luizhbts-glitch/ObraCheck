import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../data/fvs_catalog.dart';
import '../models/company_record.dart';
import '../models/diary_record.dart';
import '../models/inspection_record.dart';
import '../services/photo_service.dart';
import '../services/project_context_service.dart';
import '../services/user_profile_service.dart';
import '../theme/app_colors.dart';
import '../utils/app_date_utils.dart';
import '../utils/diary_location_formatter.dart';
import '../utils/project_scope.dart';
import '../widgets/photo_viewer.dart';
import 'inspection_screen.dart';
import 'select_fvs_screen.dart';
import 'select_location_screen.dart';

class DiaryEditScreen extends StatefulWidget {
  const DiaryEditScreen({super.key, this.diary});

  final DiaryRecord? diary;

  @override
  State<DiaryEditScreen> createState() => _DiaryEditScreenState();
}

class _DiaryEditScreenState extends State<DiaryEditScreen> {
  final ProjectContextService _projectContext = ProjectContextService.instance;
  final ImagePicker _imagePicker = ImagePicker();

  late DateTime _date;
  String _climateMorning = '';
  String _climateAfternoon = '';
  final TextEditingController _generalNotesController = TextEditingController();
  final TextEditingController _rentedMachineryController = TextEditingController();
  final TextEditingController _rentedEquipmentController = TextEditingController();
  final TextEditingController _approvedByController = TextEditingController();
  String _approvalStatus = 'pendente';

  final List<_DraftServiceEntry> _serviceEntries = [];
  final List<_DraftOwnLaborEntry> _ownLaborEntries = [];
  final List<InspectionPhotoData> _generalPhotos = [];

  bool _saving = false;

  DateTime get _today {
    return AppDateUtils.getTodayDate();
  }

  @override
  void initState() {
    super.initState();
    final base = widget.diary;
    _date = AppDateUtils.normalizeLocalDate(base?.date ?? DateTime.now());
    _climateMorning = base?.climateMorning ?? '';
    _climateAfternoon = base?.climateAfternoon ?? '';
    if (_climateMorning.isEmpty && _climateAfternoon.isEmpty) {
      final legacy = (base?.climate ?? '').trim();
      if (legacy.isNotEmpty) {
        _climateMorning = legacy;
        _climateAfternoon = legacy;
      }
    }
    _generalNotesController.text = base?.generalNotes ?? '';
    _rentedMachineryController.text = base?.rentedMachinery ?? '';
    _rentedEquipmentController.text = base?.rentedEquipment ?? '';
    _approvedByController.text = base?.approvedByName ?? '';
    _approvalStatus = (base?.approvalStatus ?? '').trim().isEmpty ? 'pendente' : (base?.approvalStatus ?? 'pendente');

    if (base != null) {
      _serviceEntries.addAll(base.serviceEntries.map(
        (e) {
          return _DraftServiceEntry(
            id: e.id,
            companyId: e.companyId,
            companyName: e.companyName,
            localRef: e.localRef,
            localLabel: e.localLabel,
            tower: e.tower,
            floor: e.floor,
            apartment: e.apartment,
            locationType: e.locationType,
            locationContext: e.locationContext,
            inspectionElement: e.inspectionElement,
            peopleCount: e.peopleCount,
            serviceStatus: e.serviceStatus,
            note: e.note,
            photos: e.photos,
            fvsCodigo: e.fvsCodigo,
            fvsNome: e.fvsNome,
          );
        },
      ));
      _generalPhotos.addAll(base.generalPhotos);
      final orderedOwnLabor = _orderedOwnLaborEntries(base.ownLaborEntries);
      _ownLaborEntries.addAll(orderedOwnLabor.map(
        (e) {
          return _DraftOwnLaborEntry(
            id: e.id,
            role: e.role,
            peopleCount: e.peopleCount,
            orderIndex: e.orderIndex,
          );
        },
      ));
    } else {
      _loadOwnLaborFromPreviousDiary();
    }
  }

  @override
  void dispose() {
    _generalNotesController.dispose();
    _rentedMachineryController.dispose();
    _rentedEquipmentController.dispose();
    _approvedByController.dispose();
    super.dispose();
  }

  void _loadOwnLaborFromPreviousDiary() {
    final box = Hive.box<DiaryRecord>('diaries');
    final currentProjectId = _projectContext.currentProjectIdSync;
    final prev = filterRecordsByProjectScope(
      box.values.where((d) => !d.deleted),
      currentProjectId: currentProjectId,
      projectId: (d) => d.projectId,
      obra: (d) => d.obra,
    ).where((d) {
      final dDate = DateTime(d.date.year, d.date.month, d.date.day);
      final thisDate = DateTime(_date.year, _date.month, _date.day);
      return dDate.isBefore(thisDate);
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    if (prev.isEmpty) return;
    final latest = prev.first;
    if (latest.ownLaborEntries.isEmpty) return;
    final orderedOwnLabor = _orderedOwnLaborEntries(latest.ownLaborEntries);
    _ownLaborEntries.addAll(orderedOwnLabor.map(
      (e) {
        return _DraftOwnLaborEntry(
          id: 'own_${DateTime.now().microsecondsSinceEpoch}_${e.role}',
          role: e.role,
          peopleCount: e.peopleCount,
          orderIndex: e.orderIndex,
        );
      },
    ));
  }

  List<DiaryOwnLaborEntry> _orderedOwnLaborEntries(List<DiaryOwnLaborEntry> entries) {
    final shouldSort = entries.any((e) => e.orderIndex != 0);
    if (!shouldSort) return entries;
    final sorted = [...entries]..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return sorted;
  }

  String _formatDate(DateTime date) {
    return AppDateUtils.formatDateBr(date);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: _today,
      initialDate: _date,
    );
    if (picked == null) return;
    if (AppDateUtils.isFutureDate(picked)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não é permitido diário com data futura.')),
      );
      return;
    }
    setState(() => _date = AppDateUtils.normalizeLocalDate(picked));
  }

  Future<InspectionPhotoData?> _pickPhoto({required bool fromCamera, required String folder}) async {
    final source = fromCamera ? ImageSource.camera : ImageSource.gallery;
    final captured = await _imagePicker.pickImage(source: source);
    if (captured == null) return null;

    if (kIsWeb) {
      final bytes = await captured.readAsBytes();
      final mime = captured.mimeType?.trim().isNotEmpty == true ? captured.mimeType!.trim() : 'image/jpeg';
      final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
      return InspectionPhotoData(
        photoUrl: dataUrl,
        storagePath: '',
        localPath: '',
        pendingSync: true,
        syncError: null,
      );
    }

    String localPath = captured.path;
    final appDir = await getApplicationDocumentsDirectory();
    final targetDirPath = '${appDir.path}/$folder';
    final targetDir = Directory(targetDirPath);
    await targetDir.create(recursive: true);

    final fileName = 'img_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final outputPath = '$targetDirPath/$fileName';
    final compressed = await FlutterImageCompress.compressAndGetFile(
      captured.path,
      outputPath,
      minWidth: 1280,
      quality: 75,
      format: CompressFormat.jpeg,
      keepExif: false,
    );

    if (compressed != null) {
      localPath = compressed.path;
    } else {
      try {
        final copied = await File(captured.path).copy(outputPath);
        localPath = copied.path;
      } catch (_) {
        localPath = captured.path;
      }
    }

    return InspectionPhotoData(
      photoUrl: '',
      storagePath: '',
      localPath: localPath,
      pendingSync: true,
      syncError: null,
    );
  }

  Future<void> _addGeneralPhoto({required bool fromCamera}) async {
    final photo = await _pickPhoto(fromCamera: fromCamera, folder: 'diary_photos/general');
    if (photo == null || !mounted) return;
    setState(() => _generalPhotos.add(photo));
  }

  Future<void> _removeGeneralPhoto(InspectionPhotoData photo) async {
    if (photo.storagePath.isNotEmpty) {
      await PhotoService.instance.deletePhoto(photo.storagePath);
    }
    await PhotoService.instance.deleteLocalPhotoIfExists(photo.localPath);
    setState(() {
      _generalPhotos.removeWhere((p) {
        return p.photoUrl == photo.photoUrl && p.localPath == photo.localPath && p.storagePath == photo.storagePath;
      });
    });
  }

  Future<void> _addServicePhoto(int index, {required bool fromCamera}) async {
    final entry = _serviceEntries[index];
    final photo = await _pickPhoto(fromCamera: fromCamera, folder: 'diary_photos/services/${entry.id}');
    if (photo == null || !mounted) return;
    setState(() {
      final nextPhotos = List<InspectionPhotoData>.from(entry.photos)..add(photo);
      _serviceEntries[index] = entry.copyWith(photos: nextPhotos);
    });
  }

  Future<void> _removeServicePhoto(int index, InspectionPhotoData photo) async {
    final entry = _serviceEntries[index];
    if (photo.storagePath.isNotEmpty) {
      await PhotoService.instance.deletePhoto(photo.storagePath);
    }
    await PhotoService.instance.deleteLocalPhotoIfExists(photo.localPath);
    setState(() {
      final nextPhotos = List<InspectionPhotoData>.from(entry.photos)
        ..removeWhere((p) {
          return p.photoUrl == photo.photoUrl && p.localPath == photo.localPath && p.storagePath == photo.storagePath;
        });
      _serviceEntries[index] = entry.copyWith(photos: nextPhotos);
    });
  }

  String _serviceCompactTitle(_DraftServiceEntry item) {
    final desc = item.fvsNome.trim().isNotEmpty ? item.fvsNome.trim() : 'Serviço';
    final towerAndFloor = _towerAndFloorLabel(item);
    final front = _serviceFrontLabel(item);
    final company = item.companyName.trim().isNotEmpty ? item.companyName.trim() : 'Empreiteiro';
    return '$desc · $towerAndFloor · $front · $company';
  }

  String _towerAndFloorLabel(_DraftServiceEntry item) {
    final tower = item.tower.trim();
    final local = item.localLabel.trim();
    final floorMatch = RegExp(r'(\d+º\s*pavimento|cobertura|rooftop|t[ée]rreo|subsolo\s*\d*)', caseSensitive: false)
        .firstMatch(local);
    final floor = floorMatch?.group(0)?.trim() ?? '';
    if (tower.isNotEmpty && floor.isNotEmpty) return 'Torre $tower $floor';
    if (tower.isNotEmpty) return 'Torre $tower';
    if (floor.isNotEmpty) return floor;
    return local.isNotEmpty ? local : 'Local não informado';
  }

  String _serviceFrontLabel(_DraftServiceEntry item) {
    var local = item.localLabel.trim();
    final tower = item.tower.trim();
    if (tower.isNotEmpty) {
      local = local.replaceFirst(RegExp('^$tower\\s*', caseSensitive: false), '').trim();
      local = local.replaceFirst(RegExp('^torre\\s+$tower\\s*', caseSensitive: false), '').trim();
    }
    local = local.replaceAll(
      RegExp(r'(\d+º\s*pavimento|cobertura|rooftop|t[ée]rreo|subsolo\s*\d*)', caseSensitive: false),
      '',
    );
    local = local.replaceAll(RegExp(r'[-–•]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (local.isNotEmpty) return local.toLowerCase();
    final fallback = item.localRef.trim();
    if (fallback.isNotEmpty) return fallback.toLowerCase();
    return 'frente geral';
  }

  ButtonStyle _compactTextButtonStyle() {
    return TextButton.styleFrom(
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      minimumSize: const Size(0, 30),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      textStyle: const TextStyle(fontSize: 12),
    );
  }

  Future<void> _openServicePhotosGallery(int index) async {
    final entry = _serviceEntries[index];
    await _openPhotoGallerySheet(
      title: 'Fotos do serviço',
      photos: entry.photos,
      onDeleted: (photo) => _removeServicePhoto(index, photo),
    );
  }

  List<_ConsolidatedPhotoEntry> _buildConsolidatedGeneralPhotos() {
    final consolidated = <_ConsolidatedPhotoEntry>[];
    for (var i = 0; i < _serviceEntries.length; i++) {
      for (final photo in _serviceEntries[i].photos) {
        consolidated.add(_ConsolidatedPhotoEntry(photo: photo, source: _PhotoSource.service, serviceIndex: i));
      }
    }
    for (final photo in _generalPhotos) {
      consolidated.add(_ConsolidatedPhotoEntry(photo: photo, source: _PhotoSource.general));
    }
    return consolidated;
  }

  Future<void> _removeConsolidatedGeneralPhoto(_ConsolidatedPhotoEntry entry) async {
    if (entry.source == _PhotoSource.general) {
      await _removeGeneralPhoto(entry.photo);
      return;
    }
    final index = entry.serviceIndex;
    if (index == null || index < 0 || index >= _serviceEntries.length) return;
    await _removeServicePhoto(index, entry.photo);
  }

  Future<void> _openGeneralConsolidatedGallery() async {
    final consolidated = _buildConsolidatedGeneralPhotos();
    await _openPhotoGallerySheet(
      title: 'Fotos das ocorrências gerais',
      photos: consolidated.map((e) => e.photo).toList(growable: false),
      onDeleted: (photo) async {
        final match = consolidated.firstWhere(
          (entry) =>
              entry.photo.photoUrl == photo.photoUrl &&
              entry.photo.localPath == photo.localPath &&
              entry.photo.storagePath == photo.storagePath,
          orElse: () => _ConsolidatedPhotoEntry(photo: photo, source: _PhotoSource.general),
        );
        await _removeConsolidatedGeneralPhoto(match);
      },
    );
  }

  Future<void> _openPhotoGallerySheet({
    required String title,
    required List<InspectionPhotoData> photos,
    required Future<void> Function(InspectionPhotoData photo) onDeleted,
  }) async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fechar galeria',
      barrierColor: Colors.black54,
      transitionDuration: Duration.zero,
      pageBuilder: (ctx, animation, secondaryAnimation) {
        return SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Material(
              color: Theme.of(ctx).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 8),
                    if (photos.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('Nenhuma foto cadastrada.'),
                      )
                    else
                      SizedBox(
                        height: MediaQuery.of(ctx).size.height * 0.55,
                        child: SingleChildScrollView(
                          child: PhotoViewerGrid(
                            photos: photos,
                            onDeleted: onDeleted,
                            crossAxisCount: 3,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmRemoveOwnLabor(int index) async {
    final item = _ownLaborEntries[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir cargo'),
        content: Text('Deseja excluir "${item.role}" da mão de obra própria?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _ownLaborEntries.removeAt(index));
  }

  Future<void> _addServiceEntry() async {
    final company = await _pickCompany();
    if (!mounted || company == null) return;

    final fvsSelection = await _pickFvsSelection();
    if (!mounted || fvsSelection == null) return;
    final location = await _pickLocationForFvs(
      template: fvsSelection.template,
      locationContext: fvsSelection.locationContext,
    );
    if (!mounted || location == null) return;

    final tower = (location['torre'] ?? '').toString().trim();
    final floor = _parseFloor(location['andar']);
    final apartment = (location['apto'] ?? '').toString().trim();
    final localRef = (location['localRef'] ?? location['apto'] ?? '').toString().trim();
    final localLabel =
        (location['localLabel'] ?? location['ambiente'] ?? location['apto'] ?? localRef).toString().trim();
    final locationType = (location['locationType'] ?? '').toString().trim();

    setState(() {
      _serviceEntries.add(
        _DraftServiceEntry(
          id: 'srv_${DateTime.now().microsecondsSinceEpoch}',
          companyId: company.id,
          companyName: company.nome,
          localRef: localRef,
          localLabel: DiaryLocationFormatter.formatLocation(
            localLabel: localLabel,
            localRef: localRef,
            tower: tower,
          ),
          tower: tower,
          floor: floor,
          apartment: apartment,
          locationType: locationType,
          locationContext: fvsSelection.locationContext,
          inspectionElement: fvsSelection.inspectionElement,
          peopleCount: 1,
          serviceStatus: '',
          note: '',
          fvsCodigo: fvsSelection.template.codigo,
          fvsNome: fvsSelection.template.nome,
        ),
      );
    });
  }

  int _parseFloor(dynamic value) {
    if (value is int) return value;
    return int.tryParse((value ?? '').toString().trim()) ?? 0;
  }

  FvsTemplate? _findFvsTemplateByCode(String code) {
    final normalized = code.trim();
    if (normalized.isEmpty) return null;
    return FvsCatalog.all.where((t) => t.codigo == normalized).firstOrNull;
  }

  Future<SelectFvsResult?> _pickFvsSelection({
    String? initialTower,
    int? initialFloor,
    String? initialLocalLabel,
    String? initialLocalRef,
  }) async {
    return Navigator.push<SelectFvsResult>(
      context,
      MaterialPageRoute(
        builder: (_) => SelectFvsScreen(
          torre: initialTower,
          andar: initialFloor,
          localLabel: initialLocalLabel,
          localRef: initialLocalRef,
          hideFinalizedHint: true,
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _pickLocationForFvs({
    required FvsTemplate template,
    required String locationContext,
  }) async {
    final location = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => SelectLocationScreen(
          title: 'Diário – Escolher local',
          autoOpenFvsOnMap: false,
          template: template,
          locationContext: locationContext,
        ),
      ),
    );
    if (!mounted || location == null) return null;
    return location;
  }

  Future<void> _pickServiceCompany(int index) async {
    final company = await _pickCompany();
    if (!mounted || company == null) return;
    setState(() {
      _serviceEntries[index] = _serviceEntries[index].copyWith(companyId: company.id, companyName: company.nome);
    });
  }

  Future<void> _pickServiceLocation(int index) async {
    final item = _serviceEntries[index];
    final template = _findFvsTemplateByCode(item.fvsCodigo);
    if (template == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione a FVS antes de definir o local.')),
      );
      return;
    }

    final location = await _pickLocationForFvs(
      template: template,
      locationContext: item.locationContext,
    );
    if (!mounted || location == null) return;
    final tower = (location['torre'] ?? '').toString().trim();
    final floor = _parseFloor(location['andar']);
    final apartment = (location['apto'] ?? '').toString().trim();
    final localRef = (location['localRef'] ?? location['apto'] ?? '').toString().trim();
    final localLabel =
        (location['localLabel'] ?? location['ambiente'] ?? location['apto'] ?? localRef).toString().trim();
    final locationType = (location['locationType'] ?? '').toString().trim();

    setState(() {
      _serviceEntries[index] = _serviceEntries[index].copyWith(
        localRef: localRef,
        localLabel: DiaryLocationFormatter.formatLocation(
          localLabel: localLabel,
          localRef: localRef,
          tower: tower,
        ),
        tower: tower,
        floor: floor,
        apartment: apartment,
        locationType: locationType,
      );
    });
  }

  Future<void> _pickServiceFvs(int index) async {
    final item = _serviceEntries[index];
    final fvsSelection = await _pickFvsSelection(
      initialTower: item.tower,
      initialFloor: item.floor > 0 ? item.floor : null,
      initialLocalLabel: item.localLabel,
      initialLocalRef: item.localRef,
    );
    if (!mounted || fvsSelection == null) return;
    setState(() {
      _serviceEntries[index] = _serviceEntries[index].copyWith(
        fvsCodigo: fvsSelection.template.codigo,
        fvsNome: fvsSelection.template.nome,
        locationContext: fvsSelection.locationContext,
        inspectionElement: fvsSelection.inspectionElement,
      );
    });
  }

  Set<String> getUsedCompanyIds(DiaryRecord diary) {
    return diary.serviceEntries
        .map((entry) => entry.companyId.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Set<String> _getUsedCompanyIdsForCurrentDraft() {
    if (_serviceEntries.isNotEmpty) {
      return _serviceEntries
          .map((entry) => entry.companyId.trim())
          .where((id) => id.isNotEmpty)
          .toSet();
    }
    final diary = widget.diary;
    if (diary == null) return <String>{};
    return getUsedCompanyIds(diary);
  }

  Future<CompanyRecord?> _pickCompany() async {
    final box = Hive.box<CompanyRecord>('companies');
    final currentProjectId = _projectContext.currentProjectIdSync;
    final companies = filterRecordsByProjectScope(
      box.values.where((c) => !c.deleted),
      currentProjectId: currentProjectId,
      projectId: (c) => c.projectId,
    ).toList()
      ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
    final usedCompanyIds = _getUsedCompanyIdsForCurrentDraft();

    if (companies.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhuma empresa disponível para a obra ativa.')),
      );
      return null;
    }

    return showModalBottomSheet<CompanyRecord>(
      context: context,
      builder: (context) {
        final appColors = context.appColors;
        return SafeArea(
          child: ListView(
            children: [
              const ListTile(title: Text('Selecionar empreiteiro', style: TextStyle(fontWeight: FontWeight.w700))),
              ...companies.map(
                (c) {
                  final isUsed = usedCompanyIds.contains(c.id);
                  final titleColor = isUsed ? appColors.textPrimary.withValues(alpha: 0.58) : appColors.textPrimary;
                  final subtitleColor = isUsed ? appColors.textSecondary.withValues(alpha: 0.46) : appColors.textSecondary;
                  return Opacity(
                    opacity: isUsed ? 0.78 : 1,
                    child: ListTile(
                      title: Text(c.nome, style: TextStyle(color: titleColor)),
                      subtitle: Text(c.especialidade, style: TextStyle(color: subtitleColor)),
                      trailing: isUsed
                          ? Icon(
                              Icons.check_circle_outline,
                              size: 18,
                              color: appColors.textSecondary.withValues(alpha: 0.5),
                            )
                          : null,
                      onTap: () => Navigator.pop(context, c),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addOwnLaborEntry() async {
    final entry = await _showOwnLaborDialog(
      initial: _DraftOwnLaborEntry(
        id: 'own_${DateTime.now().microsecondsSinceEpoch}',
        role: '',
        peopleCount: 1,
        orderIndex: _ownLaborEntries.length,
      ),
    );
    if (entry == null || !mounted) return;
    setState(() => _ownLaborEntries.add(entry));
  }

  Future<_DraftOwnLaborEntry?> _showOwnLaborDialog({required _DraftOwnLaborEntry initial}) async {
    final roleController = TextEditingController(text: initial.role);
    final peopleController = TextEditingController(text: initial.peopleCount.toString());
    final result = await showDialog<_DraftOwnLaborEntry>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Mão de obra própria'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: roleController,
                  decoration: const InputDecoration(labelText: 'Função', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: peopleController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Quantidade de pessoas', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                final role = roleController.text.trim();
                final people = int.tryParse(peopleController.text.trim()) ?? 0;
                if (role.isEmpty || people <= 0) return;
                Navigator.pop(context, initial.copyWith(role: role, peopleCount: people));
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
    roleController.dispose();
    peopleController.dispose();
    return result;
  }

  Future<void> _save() async {
    if (_saving) return;
    if (AppDateUtils.isFutureDate(_date)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não é permitido salvar diário com data futura.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final box = Hive.box<DiaryRecord>('diaries');
      final now = DateTime.now();
      final currentProjectId = _projectContext.currentProjectIdSync;
      final currentProjectName = _projectContext.currentProjectNameSync;
      final id = widget.diary?.id ??
          'diary:$currentProjectId:${_date.year.toString().padLeft(4, '0')}${_date.month.toString().padLeft(2, '0')}${_date.day.toString().padLeft(2, '0')}';
      final createdAt = widget.diary?.createdAt ?? now;
      final profile = await UserProfileService.instance.getCurrentUserProfile();
      final generatedBy = (profile?.nome ?? '').trim();

      final record = DiaryRecord(
        id: id,
        projectId: currentProjectId,
        obra: currentProjectName,
        date: AppDateUtils.normalizeLocalDate(_date),
        climate: 'Manhã: $_climateMorning | Tarde: $_climateAfternoon',
        generalNotes: _generalNotesController.text.trim(),
        serviceEntries: _serviceEntries
            .map(
              (e) => DiaryServiceEntry(
                id: e.id,
                companyId: e.companyId,
                companyName: e.companyName,
                localRef: e.localRef,
                localLabel: e.localLabel,
                tower: e.tower,
                floor: e.floor,
                apartment: e.apartment,
                locationType: e.locationType,
                locationContext: e.locationContext,
                inspectionElement: e.inspectionElement,
                peopleCount: e.peopleCount,
                serviceStatus: e.serviceStatus,
                note: e.note,
                photos: e.photos,
                fvsCodigo: e.fvsCodigo,
                fvsNome: e.fvsNome,
              ),
            )
            .toList(),
        ownLaborEntries: _ownLaborEntries
            .asMap()
            .entries
            .map(
              (entry) => DiaryOwnLaborEntry(
                id: entry.value.id,
                role: entry.value.role,
                peopleCount: entry.value.peopleCount,
                orderIndex: entry.key,
              ),
            )
            .toList(),
        generalPhotos: _generalPhotos,
        createdAt: createdAt,
        updatedAt: now,
        deleted: false,
        pendingSync: true,
        deletedAt: null,
        climateMorning: _climateMorning,
        climateAfternoon: _climateAfternoon,
        rentedMachinery: _rentedMachineryController.text.trim(),
        rentedEquipment: _rentedEquipmentController.text.trim(),
        createdByName: generatedBy.isNotEmpty ? generatedBy : (widget.diary?.createdByName ?? ''),
        approvedByName: _approvedByController.text.trim(),
        approvalStatus: _approvalStatus,
      );

      await box.put(id, record);
      if (!mounted) return;
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _climateChip(String label, String value, ValueChanged<String> onChanged) {
    final options = ['Ensolarado', 'Nublado', 'Chuvoso'];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('$label:', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
        ...options.map(
          (o) => ChoiceChip(
            label: Text(o, style: const TextStyle(fontSize: 12)),
            selected: value == o,
            onSelected: (_) => setState(() => onChanged(o)),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );
  }

  Future<void> _openServiceFvs(int index) async {
    final item = _serviceEntries[index];
    final fvsCode = item.fvsCodigo.trim();
    if (fvsCode.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione a FVS do card antes de abrir.')),
      );
      return;
    }

    final template = FvsCatalog.all.where((t) => t.codigo == fvsCode).firstOrNull;
    if (template == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('FVS $fvsCode não encontrada no catálogo.')),
      );
      return;
    }

    final location = <String, dynamic>{
      'obra': _projectContext.currentProjectNameSync,
      'torre': item.tower.trim().isNotEmpty ? item.tower.trim() : 'Outros',
      'andar': item.floor,
      'apto': item.apartment.trim().isNotEmpty ? item.apartment : item.localLabel,
      'localLabel': item.localLabel,
      'localRef': item.localRef,
      'ambiente': item.localLabel,
      'element': item.inspectionElement,
      'inspectionElement': item.inspectionElement,
      'locationType': item.locationType,
      'locationContext': item.locationContext,
    };

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InspectionScreen(
          location: location,
          template: template,
        ),
      ),
    );
  }

  Future<void> _openServiceEditMenu(int index) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.business_outlined),
              title: const Text('Editar empreiteiro'),
              onTap: () => Navigator.of(ctx).pop('company'),
            ),
            ListTile(
              leading: const Icon(Icons.place_outlined),
              title: const Text('Editar local'),
              onTap: () => Navigator.of(ctx).pop('local'),
            ),
            ListTile(
              leading: const Icon(Icons.fact_check_outlined),
              title: const Text('Editar FVS'),
              onTap: () => Navigator.of(ctx).pop('fvs'),
            ),
          ],
        ),
      ),
    );

    if (!mounted) return;
    if (action == 'company') {
      await _pickServiceCompany(index);
    } else if (action == 'local') {
      await _pickServiceLocation(index);
    } else if (action == 'fvs') {
      await _pickServiceFvs(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.diary == null ? 'Novo diário' : 'Editar diário'),
        actions: [
          IconButton(
            tooltip: 'Adicionar serviço',
            onPressed: _addServiceEntry,
            icon: const Icon(Icons.playlist_add_outlined),
          ),
          IconButton(
            tooltip: 'Salvar',
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.calendar_today_outlined, size: 18),
                        label: Text('Data: ${_formatDate(_date)}'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _climateChip(
                          'Manhã',
                          _climateMorning,
                          (v) => _climateMorning = v,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _climateChip(
                          'Tarde',
                          _climateAfternoon,
                          (v) => _climateAfternoon = v,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(child: Text('Mão de obra própria', style: TextStyle(fontWeight: FontWeight.w800))),
                      TextButton.icon(onPressed: _addOwnLaborEntry, icon: const Icon(Icons.add), label: const Text('Adicionar')),
                    ],
                  ),
                  if (_ownLaborEntries.isEmpty)
                    const Text('Nenhum lançamento de mão de obra própria no dia.')
                  else
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      buildDefaultDragHandles: false,
                      itemCount: _ownLaborEntries.length,
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) newIndex -= 1;
                          final moved = _ownLaborEntries.removeAt(oldIndex);
                          _ownLaborEntries.insert(newIndex, moved);
                        });
                      },
                      itemBuilder: (context, i) {
                        final item = _ownLaborEntries[i];
                        return Card(
                          key: ValueKey('own_labor_${item.id}'),
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Row(
                              children: [
                                ReorderableDragStartListener(
                                  index: i,
                                  child: const Padding(
                                    padding: EdgeInsets.only(right: 6),
                                    child: Icon(Icons.drag_indicator),
                                  ),
                                ),
                                Expanded(
                                  child: Text(item.role, overflow: TextOverflow.ellipsis),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => setState(
                                    () => _ownLaborEntries[i] = item.copyWith(
                                      peopleCount: (item.peopleCount - 1).clamp(0, 999),
                                    ),
                                  ),
                                  icon: const Icon(Icons.remove_circle_outline),
                                ),
                                Text(
                                  '${item.peopleCount}',
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => setState(
                                    () => _ownLaborEntries[i] = item.copyWith(
                                      peopleCount: item.peopleCount + 1,
                                    ),
                                  ),
                                  icon: const Icon(Icons.add_circle_outline),
                                ),
                                  IconButton(
                                    tooltip: 'Excluir cargo',
                                    visualDensity: VisualDensity.compact,
                                  onPressed: () => _confirmRemoveOwnLabor(i),
                                  icon: Icon(Icons.delete_outline, color: appColors.danger),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Serviços executados de terceiros',
                          style: TextStyle(fontWeight: FontWeight.w800, color: appColors.textPrimary),
                        ),
                      ),
                      TextButton.icon(onPressed: _addServiceEntry, icon: const Icon(Icons.add), label: const Text('Adicionar')),
                    ],
                  ),
                  if (_serviceEntries.isEmpty)
                    const Text('Nenhum lançamento de serviço no dia.')
                  else
                    ..._serviceEntries.asMap().entries.map((entry) {
                      final i = entry.key;
                      final item = entry.value;
                      final stripe = i.isEven;
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                          decoration: BoxDecoration(
                            color: stripe ? appColors.surface : appColors.surfaceAlt.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: appColors.border.withValues(alpha: 0.45)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: SelectableText(
                                    _serviceCompactTitle(item),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: appColors.textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 132),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            visualDensity: VisualDensity.compact,
                                            onPressed: () => setState(
                                              () => _serviceEntries[i] = item.copyWith(peopleCount: (item.peopleCount - 1).clamp(0, 999)),
                                            ),
                                            icon: const Icon(Icons.remove_circle_outline, size: 18),
                                          ),
                                          Text(
                                            'Qtd. ${item.peopleCount}',
                                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                                          ),
                                          IconButton(
                                            visualDensity: VisualDensity.compact,
                                            onPressed: () => setState(
                                              () => _serviceEntries[i] = item.copyWith(peopleCount: item.peopleCount + 1),
                                            ),
                                            icon: const Icon(Icons.add_circle_outline, size: 18),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            tooltip: 'Editar',
                                            visualDensity: VisualDensity.compact,
                                            onPressed: () => _openServiceEditMenu(i),
                                            icon: const Icon(Icons.edit_outlined, size: 19),
                                          ),
                                          IconButton(
                                            tooltip: 'Excluir',
                                            visualDensity: VisualDensity.compact,
                                            onPressed: () => setState(() => _serviceEntries.removeAt(i)),
                                            icon: Icon(Icons.delete_outline, color: appColors.danger, size: 19),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                TextButton.icon(
                                  style: _compactTextButtonStyle(),
                                  onPressed: () => _openServicePhotosGallery(i),
                                  icon: const Icon(Icons.photo_library_outlined, size: 16),
                                  label: Text('Fotos ${item.photos.length}'),
                                ),
                                const SizedBox(width: 2),
                                TextButton.icon(
                                  style: _compactTextButtonStyle(),
                                  onPressed: () => _addServicePhoto(i, fromCamera: true),
                                  icon: const Icon(Icons.photo_camera_outlined, size: 16),
                                  label: const Text('Câmera'),
                                ),
                                const SizedBox(width: 2),
                                TextButton.icon(
                                  style: _compactTextButtonStyle(),
                                  onPressed: () => _addServicePhoto(i, fromCamera: false),
                                  icon: const Icon(Icons.drive_folder_upload_outlined, size: 16),
                                  label: const Text('Galeria/arquivo'),
                                ),
                                const SizedBox(width: 2),
                                TextButton.icon(
                                  style: _compactTextButtonStyle(),
                                  onPressed: () => _openServiceFvs(i),
                                  icon: const Icon(Icons.open_in_new_outlined, size: 16),
                                  label: const Text('Abrir FVS'),
                                ),
                              ],
                            ),
                            ),
                            const Divider(height: 12),
                          ],
                        ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: TextField(
                controller: _rentedMachineryController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Maquinário alugado', border: OutlineInputBorder()),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: TextField(
                controller: _rentedEquipmentController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Equipamento alugado', border: OutlineInputBorder()),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _generalNotesController,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Ocorrências gerais do dia', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                      TextButton.icon(
                        style: _compactTextButtonStyle(),
                        onPressed: _openGeneralConsolidatedGallery,
                        icon: const Icon(Icons.photo_library_outlined, size: 16),
                        label: Text('Fotos ${_buildConsolidatedGeneralPhotos().length}'),
                      ),
                      const SizedBox(width: 2),
                      TextButton.icon(
                        style: _compactTextButtonStyle(),
                        onPressed: () => _addGeneralPhoto(fromCamera: true),
                        icon: const Icon(Icons.photo_camera_outlined, size: 16),
                        label: const Text('Câmera'),
                      ),
                      const SizedBox(width: 2),
                      TextButton.icon(
                        style: _compactTextButtonStyle(),
                        onPressed: () => _addGeneralPhoto(fromCamera: false),
                        icon: const Icon(Icons.drive_folder_upload_outlined, size: 16),
                        label: const Text('Galeria/arquivo'),
                      ),
                    ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Auditoria / aprovação',
                    style: TextStyle(fontWeight: FontWeight.w800, color: appColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _approvedByController,
                    decoration: const InputDecoration(labelText: 'Aprovado por (futuro fluxo)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _approvalStatus,
                    decoration: const InputDecoration(labelText: 'Status de aprovação', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'pendente', child: Text('Pendente')),
                      DropdownMenuItem(value: 'aprovado', child: Text('Aprovado')),
                    ],
                    onChanged: (v) => setState(() => _approvalStatus = v ?? 'pendente'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 6, 12, 12),
        child: FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Salvar diário'),
        ),
      ),
    );
  }
}

class _DraftServiceEntry {
  final String id;
  final String companyId;
  final String companyName;
  final String localRef;
  final String localLabel;
  final String tower;
  final int floor;
  final String apartment;
  final String locationType;
  final String locationContext;
  final String inspectionElement;
  final int peopleCount;
  final String serviceStatus;
  final String note;
  final List<InspectionPhotoData> photos;
  final String fvsCodigo;
  final String fvsNome;

  const _DraftServiceEntry({
    required this.id,
    required this.companyId,
    required this.companyName,
    required this.localRef,
    required this.localLabel,
    this.tower = '',
    this.floor = 0,
    this.apartment = '',
    this.locationType = '',
    this.locationContext = '',
    this.inspectionElement = '',
    required this.peopleCount,
    required this.serviceStatus,
    required this.note,
    this.photos = const [],
    this.fvsCodigo = '',
    this.fvsNome = '',
  });

  _DraftServiceEntry copyWith({
    String? id,
    String? companyId,
    String? companyName,
    String? localRef,
    String? localLabel,
    String? tower,
    int? floor,
    String? apartment,
    String? locationType,
    String? locationContext,
    String? inspectionElement,
    int? peopleCount,
    String? serviceStatus,
    String? note,
    List<InspectionPhotoData>? photos,
    String? fvsCodigo,
    String? fvsNome,
  }) {
    return _DraftServiceEntry(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      localRef: localRef ?? this.localRef,
      localLabel: localLabel ?? this.localLabel,
      tower: tower ?? this.tower,
      floor: floor ?? this.floor,
      apartment: apartment ?? this.apartment,
      locationType: locationType ?? this.locationType,
      locationContext: locationContext ?? this.locationContext,
      inspectionElement: inspectionElement ?? this.inspectionElement,
      peopleCount: peopleCount ?? this.peopleCount,
      serviceStatus: serviceStatus ?? this.serviceStatus,
      note: note ?? this.note,
      photos: photos ?? this.photos,
      fvsCodigo: fvsCodigo ?? this.fvsCodigo,
      fvsNome: fvsNome ?? this.fvsNome,
    );
  }
}

class _DraftOwnLaborEntry {
  final String id;
  final String role;
  final int peopleCount;
  final int orderIndex;

  const _DraftOwnLaborEntry({
    required this.id,
    required this.role,
    required this.peopleCount,
    this.orderIndex = 0,
  });

  _DraftOwnLaborEntry copyWith({String? id, String? role, int? peopleCount, int? orderIndex}) {
    return _DraftOwnLaborEntry(
      id: id ?? this.id,
      role: role ?? this.role,
      peopleCount: peopleCount ?? this.peopleCount,
      orderIndex: orderIndex ?? this.orderIndex,
    );
  }
}

enum _PhotoSource { service, general }

class _ConsolidatedPhotoEntry {
  final InspectionPhotoData photo;
  final _PhotoSource source;
  final int? serviceIndex;

  const _ConsolidatedPhotoEntry({
    required this.photo,
    required this.source,
    this.serviceIndex,
  });
}

