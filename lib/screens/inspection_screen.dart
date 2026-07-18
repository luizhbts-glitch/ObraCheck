import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import '../data/fvs_catalog.dart'; // FvsTemplate
import '../data/fvs_data.dart'; // FvsItem
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import '../models/company_record.dart';
import '../models/inspection_record.dart';
import '../services/inspection_draft_mapper_service.dart';
import '../services/permission_service.dart';
import '../services/project_context_service.dart';
import '../services/inspection_workflow_service.dart';
import '../services/photo_service.dart';
import '../services/user_profile_service.dart';
import '../theme/app_colors.dart';
import '../utils/fvs_icon_formatter.dart';
import '../utils/project_scope.dart';
import 'select_fvs_screen.dart';
import '../widgets/photo_viewer.dart';

enum ItemStatus { none, ok, nok, okAfterFix }

class InspectionScreen extends StatefulWidget {
  const InspectionScreen({
    super.key,
    required this.location,
    required this.template,
    this.inspectionId,
    this.returnResultOnSaveFinish = false,
    this.readOnly = false,
  });

  final Map<String, dynamic> location;
  final FvsTemplate template;
  final String? inspectionId;
  final bool returnResultOnSaveFinish;
  final bool readOnly;

  @override
  State<InspectionScreen> createState() => _InspectionScreenState();
}

class _InspectionScreenState extends State<InspectionScreen> {
  final Map<int, ItemStatus> _status = {};
  final Map<int, TextEditingController> _obsControllers = {};
  final Map<int, List<InspectionPhotoData>> _photoPathsByItem = {};
  final Map<int, String> _measuredValueTextByItem = {};
  final Map<int, String> _measuredUnitByItem = {};
  final Map<int, String> _technicalNoteByItem = {};
  final Map<int, List<String>> _sampledLocationsByItem = {};
  final Map<int, String?> _ncCompanyIdByItem = {};
  final Map<int, String?> _ncCompanyNameByItem = {};
  final ImagePicker _imagePicker = ImagePicker();
  bool _isLocked = false;
  bool _dirty = false;
  bool _dirtySetScheduled = false;
  bool _suppressDirtyTracking = false;
  String? _currentRecordId;
  late FvsTemplate _activeTemplate;
  late String _locationInspectionElement;
  String? _selectedInspectionElement;
  String? _selectedOperationalSheetId;
  String? _selectedOperationalSheetLabel;
  final PermissionService _permissionService = PermissionService.instance;

  Future<XFile?> _captureWithSystemCameraPreferred() async {
    try {
      // Android/iOS: image_picker já delega para o app nativo de câmera.
      // Web: mantém comportamento atual do plugin.
      final captured = await _imagePicker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (captured != null) return captured;

      // Fallback para cenários em que o processo foi recriado durante a câmera.
      final lost = await _imagePicker.retrieveLostData();
      if (!lost.isEmpty && lost.files != null && lost.files!.isNotEmpty) {
        return lost.files!.first;
      }
      return null;
    } catch (e) {
      debugPrint('[PHOTO][WARN] Falha ao abrir câmera padrão: $e');
      // Fallback seguro: tenta novamente com chamada direta padrão do plugin.
      return _imagePicker.pickImage(source: ImageSource.camera);
    }
  }

  bool get _canOpenNc => _permissionService.has(AppPermission.openNc);
  bool get _canFinalizeInspection =>
      _permissionService.has(AppPermission.finalizeInspection);

  void _safeSetState(VoidCallback updater) {
    if (!mounted) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(updater);
      });
      return;
    }
    setState(updater);
  }

  void _showSnackBarSafe(String message) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    });
  }

  void _markDirty() {
    if (_suppressDirtyTracking || _isLocked || widget.readOnly) return;
    if (_dirty) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      if (_dirtySetScheduled) return;
      _dirtySetScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _dirtySetScheduled = false;
        if (!mounted || _dirty) return;
        setState(() => _dirty = true);
      });
      return;
    }
    setState(() => _dirty = true);
  }

  Future<UserProfileData?> _currentUserProfile() async {
    return UserProfileService.instance.getCurrentUserProfile();
  }

  bool _isProfileIncomplete(UserProfileData? profile) {
    final nome = profile?.nome;
    final cargo = profile?.cargo;
    final nomeValido = nome != null && nome.trim().isNotEmpty;
    final cargoValido = cargo != null && cargo.trim().isNotEmpty;
    return !nomeValido || !cargoValido;
  }

  Future<bool> _ensureProfileCompleteForFvs() async {
    final profile = await _currentUserProfile();
    if (!_isProfileIncomplete(profile)) return true;

    if (!mounted) return false;
    final goToProfile = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Perfil incompleto'),
          content: const Text(
            'Complete seu perfil antes de salvar a FVS.\nÉ obrigatório informar nome e cargo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Ir para perfil'),
            ),
          ],
        );
      },
    );

    if (goToProfile == true && mounted) {
      await Navigator.pushNamed(context, '/profile');
    }

    return false;
  }

  Future<CompanyRecord?> _pickNcCompany({String? initialCompanyId}) async {
    if (!_canOpenNc) {
      _permissionService.ensure(context, AppPermission.openNc);
      return null;
    }
    final companiesBox = Hive.box<CompanyRecord>('companies');
    final currentProjectId =
        ProjectContextService.instance.currentProjectIdSync;
    final companies =
        companiesBox.values
            .where(
              (c) =>
                  !c.deleted &&
                  matchesActiveProject(
                    activeProjectId: currentProjectId,
                    recordProjectId: c.projectId,
                  ),
            )
            .toList()
          ..sort(
            (a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()),
          );

    if (companies.isEmpty) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhum empreiteiro cadastrado para vincular à NC.'),
        ),
      );
      return null;
    }

    CompanyRecord? selected;
    if (initialCompanyId != null && initialCompanyId.trim().isNotEmpty) {
      for (final company in companies) {
        if (company.id == initialCompanyId) {
          selected = company;
          break;
        }
      }
    }
    final result = await showDialog<CompanyRecord>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Selecionar empreiteiro da NC'),
              content: DropdownButtonFormField<String>(
                initialValue: selected?.id,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Empreiteiro',
                  border: OutlineInputBorder(),
                ),
                items: companies
                    .map(
                      (c) => DropdownMenuItem<String>(
                        value: c.id,
                        child: Text(c.nome),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setDialogState(() {
                    selected = companies.firstWhere((c) => c.id == value);
                  });
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: selected == null
                      ? null
                      : () => Navigator.pop(context, selected),
                  child: const Text('Confirmar'),
                ),
              ],
            );
          },
        );
      },
    );

    return result;
  }

  Future<void> _pickNcCompanyForItem(int itemIndex) async {
    final selected = await _pickNcCompany(
      initialCompanyId: _ncCompanyIdByItem[itemIndex],
    );
    if (selected == null || !mounted) return;
    setState(() {
      _ncCompanyIdByItem[itemIndex] = selected.id;
      _ncCompanyNameByItem[itemIndex] = selected.nome;
      _dirty = true;
    });
  }

  void _clearNcCompanyForItem(int itemIndex) {
    setState(() {
      _ncCompanyIdByItem.remove(itemIndex);
      _ncCompanyNameByItem.remove(itemIndex);
      _dirty = true;
    });
  }

  @override
  void initState() {
    super.initState();
    _activeTemplate = widget.template;
    _locationInspectionElement = InspectionRecord.normalizeInspectionElement(
      widget.location['element']?.toString().isNotEmpty == true
          ? widget.location['element']?.toString()
          : widget.location['inspectionElement']?.toString(),
    );
    _selectedInspectionElement = _locationInspectionElement;
    _selectedOperationalSheetId = (widget.location['operationalSheetId'] ?? '')
        .toString()
        .trim();
    _selectedOperationalSheetLabel =
        (widget.location['operationalSheetLabel'] ?? '').toString().trim();
    if (widget.inspectionId != null && widget.inspectionId!.trim().isNotEmpty) {
      _loadInspectionById(widget.inspectionId!.trim());
    } else {
      _loadDraft();
    }
  }

  ItemStatus _statusFromString(String statusStr) {
    switch (statusStr) {
      case 'ok':
        return ItemStatus.ok;
      case 'nok':
        return ItemStatus.nok;
      case 'okAfterFix':
        return ItemStatus.okAfterFix;
      default:
        return ItemStatus.none;
    }
  }

  void _applyDraftStateToForm(InspectionDraftFormState formState) {
    _suppressDirtyTracking = true;
    _status.clear();
    _photoPathsByItem.clear();
    _measuredValueTextByItem.clear();
    _measuredUnitByItem.clear();
    _technicalNoteByItem.clear();
    _sampledLocationsByItem.clear();
    _ncCompanyIdByItem.clear();
    _ncCompanyNameByItem.clear();
    for (final c in _obsControllers.values) {
      c.dispose();
    }
    _obsControllers.clear();

    for (final entry in formState.statusByIndex.entries) {
      _status[entry.key] = _statusFromString(entry.value);
    }

    for (final entry in formState.obsByIndex.entries) {
      _obsControllers[entry.key] = TextEditingController(text: entry.value);
    }

    for (final entry in formState.photosByIndex.entries) {
      _photoPathsByItem[entry.key] = List<InspectionPhotoData>.from(
        entry.value,
      );
    }
    for (final entry in formState.measuredValueByIndex.entries) {
      final value = entry.value;
      if (value != null) {
        _measuredValueTextByItem[entry.key] = value.toString();
      }
    }
    for (final entry in formState.measuredUnitByIndex.entries) {
      _measuredUnitByItem[entry.key] = entry.value;
    }
    for (final entry in formState.technicalNoteByIndex.entries) {
      _technicalNoteByItem[entry.key] = entry.value;
    }
    for (final entry in formState.sampledLocationsByIndex.entries) {
      _sampledLocationsByItem[entry.key] = List<String>.from(entry.value);
    }

    for (final entry in formState.ncCompanyIdByIndex.entries) {
      _ncCompanyIdByItem[entry.key] = entry.value;
    }
    for (final entry in formState.ncCompanyNameByIndex.entries) {
      _ncCompanyNameByItem[entry.key] = entry.value;
    }
    _dirty = false;
    _suppressDirtyTracking = false;
  }

  Future<void> _loadInspectionById(String recordId) async {
    try {
      final box = Hive.box<InspectionRecord>('inspections');
      final record = box.get(recordId);
      if (record == null) return;

      _currentRecordId = record.id;
      _isLocked = record.isLockedState;
      _selectedInspectionElement = _locationInspectionElement;
      _selectedOperationalSheetId = record.operationalSheetId?.trim();
      _selectedOperationalSheetLabel = record.operationalSheetLabel?.trim();
      final formState = InspectionDraftMapperService.instance
          .mapRecordToFormState(record);
      _applyDraftStateToForm(formState);

      _safeSetState(() {});
    } catch (_) {
      // mantém fluxo da UI
    }
  }

  String _getDraftKey() {
    final projectId =
        currentProjectIdOrNull(widget.location['projectId']?.toString()) ??
        requireCurrentProjectId(
          ProjectContextService.instance.currentProjectIdSync,
        );
    final obra = widget.location['obra'] ?? '';
    final torre = widget.location['torre'] ?? '';
    final andar = widget.location['andar'] ?? '';
    final localRef =
        widget.location['localRef'] ?? (widget.location['apto'] ?? '');
    final fvsCodigo = _activeTemplate.codigo;
    final elementKey = InspectionRecord.inspectionElementKey(
      _selectedInspectionElement,
    );
    final operationalSheetKey = (_selectedOperationalSheetId ?? '').trim();
    final key = buildInspectionDraftKey(
      projectId: projectId,
      obra: '$obra',
      torre: '$torre',
      andar: '$andar',
      localRef: '$localRef',
      fvsCodigo: fvsCodigo,
      inspectionElement: elementKey,
      operationalSheetId: operationalSheetKey,
    );
    if (kDebugMode) {
      debugPrint('[DRAFT][KEY] projectId=$projectId key=$key');
    }
    return key;
  }

  String _getLegacyDraftKey() {
    final obra = widget.location['obra'] ?? '';
    final torre = widget.location['torre'] ?? '';
    final andar = widget.location['andar'] ?? '';
    final localRef =
        widget.location['localRef'] ?? (widget.location['apto'] ?? '');
    final fvsCodigo = _activeTemplate.codigo;
    return buildInspectionLegacyDraftKey(
      obra: '$obra',
      torre: '$torre',
      andar: '$andar',
      localRef: '$localRef',
      fvsCodigo: fvsCodigo,
    );
  }

  String get _draftRecordId => _getDraftKey();

  Future<void> _loadDraft() async {
    try {
      final draftKey = _getDraftKey();
      final legacyDraftKey = _getLegacyDraftKey();
      final prefs = Hive.box('prefs');
      final box = Hive.box<InspectionRecord>('inspections');
      var record = InspectionDraftMapperService.instance.resolveDraftRecord(
        inspectionsBox: box,
        prefs: prefs,
        draftKey: draftKey,
        fallbackRecordId: _draftRecordId,
        currentProjectId: ProjectContextService.instance.currentProjectIdSync,
      );

      // Compatibilidade legada só é permitida quando o fluxo atual não informa elemento.
      if (record == null && _locationInspectionElement.isEmpty) {
        record = InspectionDraftMapperService.instance.resolveDraftRecord(
          inspectionsBox: box,
          prefs: prefs,
          draftKey: legacyDraftKey,
          fallbackRecordId: legacyDraftKey,
          currentProjectId: ProjectContextService.instance.currentProjectIdSync,
        );
      }

      if (record == null) return;

      _currentRecordId = record.id;
      _isLocked = record.isLockedState;
      _selectedInspectionElement = _locationInspectionElement;
      _selectedOperationalSheetId = record.operationalSheetId?.trim();
      _selectedOperationalSheetLabel = record.operationalSheetLabel?.trim();
      final formState = InspectionDraftMapperService.instance
          .mapRecordToFormState(record);
      _applyDraftStateToForm(formState);

      _safeSetState(() {});
      _showSnackBarSafe(
        _isLocked ? 'Inspeção final carregada (travada)' : 'Rascunho carregado',
      );
    } catch (_) {
      // Silently fail if draft loading fails
    }
  }

  @override
  void dispose() {
    for (final c in _obsControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _obs(int index) {
    return _obsControllers.putIfAbsent(index, () {
      final controller = TextEditingController();
      controller.addListener(() {
        _markDirty();
      });
      return controller;
    });
  }

  List<InspectionPhotoData> _photosForItem(int index) {
    return List<InspectionPhotoData>.from(_photoPathsByItem[index] ?? const []);
  }

  Map<int, String> _statusByIndex() {
    final map = <int, String>{};
    for (int i = 0; i < _activeTemplate.itens.length; i++) {
      map[i] = (_status[i] ?? ItemStatus.none).name;
    }
    return map;
  }

  Map<int, String> _obsByIndex() {
    final map = <int, String>{};
    for (int i = 0; i < _activeTemplate.itens.length; i++) {
      map[i] = _obs(i).text.trim();
    }
    return map;
  }

  Map<int, double?> _measuredValueByIndex() {
    final map = <int, double?>{};
    for (int i = 0; i < _activeTemplate.itens.length; i++) {
      final raw = (_measuredValueTextByItem[i] ?? '').trim().replaceAll(
        ',',
        '.',
      );
      map[i] = raw.isEmpty ? null : double.tryParse(raw);
    }
    return map;
  }

  Map<int, String> _measuredUnitByIndex() {
    final map = <int, String>{};
    for (int i = 0; i < _activeTemplate.itens.length; i++) {
      map[i] = (_measuredUnitByItem[i] ?? '').trim();
    }
    return map;
  }

  Map<int, String> _technicalNoteByIndex() {
    final map = <int, String>{};
    for (int i = 0; i < _activeTemplate.itens.length; i++) {
      map[i] = (_technicalNoteByItem[i] ?? '').trim();
    }
    return map;
  }

  Map<int, List<String>> _sampledLocationsByIndex() {
    final map = <int, List<String>>{};
    for (int i = 0; i < _activeTemplate.itens.length; i++) {
      map[i] = List<String>.from(
        _sampledLocationsByItem[i] ?? const <String>[],
      );
    }
    return map;
  }

  String? _firstNcCompanyIdFromForm() {
    for (int i = 0; i < _activeTemplate.itens.length; i++) {
      if ((_status[i] ?? ItemStatus.none) != ItemStatus.nok) continue;
      final id = _ncCompanyIdByItem[i]?.trim();
      if (id != null && id.isNotEmpty) return id;
    }
    return null;
  }

  Future<bool> _confirmExitWithoutSaving() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Alterações não salvas'),
          content: const Text(
            'Têm alterações não salvas. Deseja sair sem salvar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Sair sem salvar'),
            ),
          ],
        );
      },
    );
    return leave == true;
  }

  Future<String?> _askCorrectionNote() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Descreva a correção realizada'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText:
                  'Ex.: Refeito alinhamento e regularização da superfície',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isEmpty) return;
                Navigator.pop(context, text);
              },
              child: const Text('Confirmar XO'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
  }

  // ======= VALIDAÇÕES (V1) =======

  bool get _hasUnmarked {
    final validation = InspectionWorkflowService.instance.validateFinalize(
      template: _activeTemplate,
      locationContext: widget.location['locationContext']?.toString(),
      statusByIndex: _statusByIndex(),
      obsByIndex: _obsByIndex(),
      photosByIndex: {
        for (int i = 0; i < _activeTemplate.itens.length; i++)
          i: _photosForItem(i),
      },
      measuredValueByIndex: _measuredValueByIndex(),
      technicalNoteByIndex: _technicalNoteByIndex(),
    );
    return validation.hasUnmarked;
  }

  List<int> get _nokWithoutObs {
    final validation = InspectionWorkflowService.instance.validateFinalize(
      template: _activeTemplate,
      locationContext: widget.location['locationContext']?.toString(),
      statusByIndex: _statusByIndex(),
      obsByIndex: _obsByIndex(),
      photosByIndex: {
        for (int i = 0; i < _activeTemplate.itens.length; i++)
          i: _photosForItem(i),
      },
      measuredValueByIndex: _measuredValueByIndex(),
      technicalNoteByIndex: _technicalNoteByIndex(),
    );
    return validation.nokWithoutObs;
  }

  List<int> get _itemsMissingRequiredPhoto {
    final validation = InspectionWorkflowService.instance.validateFinalize(
      template: _activeTemplate,
      locationContext: widget.location['locationContext']?.toString(),
      statusByIndex: _statusByIndex(),
      obsByIndex: _obsByIndex(),
      photosByIndex: {
        for (int i = 0; i < _activeTemplate.itens.length; i++)
          i: _photosForItem(i),
      },
      measuredValueByIndex: _measuredValueByIndex(),
      technicalNoteByIndex: _technicalNoteByIndex(),
    );
    return validation.itemsMissingRequiredPhoto;
  }

  Map<String, int> get _counts {
    int ok = 0, nok = 0, xo = 0, none = 0;
    for (int i = 0; i < _activeTemplate.itens.length; i++) {
      switch (_status[i] ?? ItemStatus.none) {
        case ItemStatus.ok:
          ok++;
          break;
        case ItemStatus.nok:
          nok++;
          break;
        case ItemStatus.okAfterFix:
          xo++;
          break;
        case ItemStatus.none:
          none++;
          break;
      }
    }
    return {"ok": ok, "nok": nok, "xo": xo, "none": none};
  }

  bool get _hasPendingChanges {
    for (int i = 0; i < _activeTemplate.itens.length; i++) {
      if ((_status[i] ?? ItemStatus.none) != ItemStatus.none) return true;
      if (_obs(i).text.trim().isNotEmpty) return true;
      if ((_photoPathsByItem[i] ?? const <InspectionPhotoData>[]).isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  Future<void> _addNcPhoto(int itemIndex) async {
    if (_isLocked || widget.readOnly) return;
    final current =
        _photoPathsByItem[itemIndex] ?? const <InspectionPhotoData>[];
    if (current.length >= 5) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Máximo de 5 fotos por item.')),
      );
      return;
    }

    final captured = await _captureWithSystemCameraPreferred();
    if (captured == null) return;

    if (kIsWeb) {
      final bytes = await captured.readAsBytes();
      final mime = captured.mimeType?.trim().isNotEmpty == true
          ? captured.mimeType!.trim()
          : 'image/jpeg';
      final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
      debugPrint(
        '[PHOTO][CAPTURE][WEB] item=$itemIndex bytes=${bytes.length} mime=$mime '
        'photoUrlType=data-url localPath=empty',
      );

      setState(() {
        final list = List<InspectionPhotoData>.from(
          _photoPathsByItem[itemIndex] ?? const [],
        );
        list.add(
          InspectionPhotoData(
            photoUrl: dataUrl,
            storagePath: '',
            localPath: '',
            pendingSync: true,
            syncError: null,
          ),
        );
        _photoPathsByItem[itemIndex] = list;
        _dirty = true;
      });
      return;
    }

    String localPath = captured.path;
    if (!kIsWeb) {
      final appDir = await getApplicationDocumentsDirectory();
      final inspectionId = _currentRecordId ?? _draftRecordId;
      final targetDirPath = '${appDir.path}/nc_photos/$inspectionId/$itemIndex';
      final targetDir = Directory(targetDirPath);
      await targetDir.create(recursive: true);

      final fileName = 'nc_${DateTime.now().millisecondsSinceEpoch}.jpg';
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
        } catch (e) {
          debugPrint(
            '[PHOTO][WARN] Falha ao copiar foto para diretório persistente: $e',
          );
          localPath = captured.path;
        }
      }
      debugPrint('[PHOTO] Foto salva localmente em: $localPath');
    }

    setState(() {
      final list = List<InspectionPhotoData>.from(
        _photoPathsByItem[itemIndex] ?? const [],
      );
      list.add(
        InspectionPhotoData(
          photoUrl: '',
          storagePath: '',
          localPath: localPath,
          pendingSync: true,
          syncError: null,
        ),
      );
      _photoPathsByItem[itemIndex] = list;
      _dirty = true;
    });
  }

  Future<void> _removeNcPhoto(int itemIndex, InspectionPhotoData photo) async {
    if (photo.storagePath.isNotEmpty) {
      await PhotoService.instance.deletePhoto(photo.storagePath);
    }
    await PhotoService.instance.deleteLocalPhotoIfExists(photo.localPath);
    setState(() {
      final list = List<InspectionPhotoData>.from(
        _photoPathsByItem[itemIndex] ?? const [],
      );
      list.removeWhere(
        (e) =>
            e.photoUrl == photo.photoUrl &&
            e.storagePath == photo.storagePath &&
            e.localPath == photo.localPath,
      );
      _photoPathsByItem[itemIndex] = list;
      _dirty = true;
    });
  }

  Future<void> _deletePhotoFiles(Iterable<InspectionPhotoData> photos) async {
    for (final photo in photos) {
      if (photo.storagePath.isNotEmpty) {
        await PhotoService.instance.deletePhoto(photo.storagePath);
      }
      await PhotoService.instance.deleteLocalPhotoIfExists(photo.localPath);
    }
  }

  Future<void> _switchTemplate(
    FvsTemplate nextTemplate, {
    String? operationalSheetId,
    String? operationalSheetLabel,
  }) async {
    if (nextTemplate.codigo == _activeTemplate.codigo) return;
    for (final c in _obsControllers.values) {
      c.dispose();
    }
    _obsControllers.clear();
    _status.clear();
    _photoPathsByItem.clear();
    setState(() {
      _activeTemplate = nextTemplate;
      _selectedInspectionElement = _locationInspectionElement;
      _selectedOperationalSheetId = (operationalSheetId ?? '').trim();
      _selectedOperationalSheetLabel = (operationalSheetLabel ?? '').trim();
      _isLocked = false;
      _currentRecordId = null;
      _dirty = false;
    });
    await _loadDraft();
  }

  Future<void> _onPickFvsFromTop() async {
    if (_isLocked || widget.readOnly) return;
    final selected = await Navigator.push<SelectFvsResult>(
      context,
      MaterialPageRoute(
        builder: (_) => SelectFvsScreen(
          torre: widget.location['torre']?.toString(),
          andar: widget.location['andar'] is int
              ? widget.location['andar'] as int
              : null,
          localLabel: widget.location['localLabel']?.toString(),
          localRef: widget.location['localRef']?.toString(),
        ),
      ),
    );
    if (!mounted || selected == null) return;
    final sameCode = selected.template.codigo == _activeTemplate.codigo;
    final sameOperationalSheet =
        (selected.operationalSheetId?.trim() ?? '') ==
        ((_selectedOperationalSheetId ?? '').trim());
    if (sameCode && sameOperationalSheet) return;

    if (!_hasPendingChanges) {
      await _switchTemplate(
        selected.template,
        operationalSheetId: selected.operationalSheetId,
        operationalSheetLabel: selected.operationalSheetLabel,
      );
      return;
    }

    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Trocar FVS'),
        content: const Text('Existem alterações não salvas nesta tela.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('Descartar e trocar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text('Salvar rascunho e trocar'),
          ),
        ],
      ),
    );

    if (!mounted || action == null || action == 'cancel') return;
    if (action == 'save') {
      await _saveDraft(allowPopResult: false);
      _dirty = false;
    }
    if (action == 'discard') {
      final allPhotoPaths = _photoPathsByItem.values.expand((e) => e).toList();
      await _deletePhotoFiles(allPhotoPaths);
    }
    await _switchTemplate(
      selected.template,
      operationalSheetId: selected.operationalSheetId,
      operationalSheetLabel: selected.operationalSheetLabel,
    );
  }

  // ✅ NOVO: salvar rascunho (não valida pendências)
  Future<void> _saveDraft({bool allowPopResult = true}) async {
    if (_isLocked || widget.readOnly) return;
    final canProceed = await _ensureProfileCompleteForFvs();
    if (!canProceed) return;
    try {
      // 🔑 chave única do rascunho
      final draftKey = _getDraftKey();
      final recordId = _draftRecordId;

      final user = await _currentUserProfile();
      final record = await InspectionWorkflowService.instance.saveDraft(
        location: widget.location,
        template: _activeTemplate,
        draftKey: draftKey,
        draftRecordId: recordId,
        currentRecordId: _currentRecordId,
        locationContext: widget.location['locationContext']?.toString(),
        inspectionElement: _selectedInspectionElement,
        operationalSheetId: _selectedOperationalSheetId,
        operationalSheetLabel: _selectedOperationalSheetLabel,
        statusByIndex: _statusByIndex(),
        obsByIndex: _obsByIndex(),
        photosByIndex: {
          for (int i = 0; i < _activeTemplate.itens.length; i++)
            i: _photosForItem(i),
        },
        measuredValueByIndex: _measuredValueByIndex(),
        measuredUnitByIndex: _measuredUnitByIndex(),
        technicalNoteByIndex: _technicalNoteByIndex(),
        sampledLocationsByIndex: _sampledLocationsByIndex(),
        ncCompanyIdByIndex: _ncCompanyIdByItem,
        ncCompanyNameByIndex: _ncCompanyNameByItem,
        user: user,
      );
      _currentRecordId = record.id;

      if (!mounted) return;
      final hasNc = InspectionWorkflowService.instance.hasNc(record.itens);
      if (allowPopResult) {
        _dirty = false;
        Navigator.pop(context, {'action': 'rascunho', 'hasNc': hasNc});
        return;
      }
      setState(() => _isLocked = false);
      _dirty = false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Rascunho salvo.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao salvar rascunho: $e')));
    }
  }

  Future<void> _reopenInspection() async {
    try {
      final user = await _currentUserProfile();
      final draftKey = _getDraftKey();
      final recordId = _draftRecordId;
      final record = await InspectionWorkflowService.instance.saveDraft(
        location: widget.location,
        template: _activeTemplate,
        draftKey: draftKey,
        draftRecordId: recordId,
        currentRecordId: _currentRecordId,
        locationContext: widget.location['locationContext']?.toString(),
        inspectionElement: _selectedInspectionElement,
        operationalSheetId: _selectedOperationalSheetId,
        operationalSheetLabel: _selectedOperationalSheetLabel,
        statusByIndex: _statusByIndex(),
        obsByIndex: _obsByIndex(),
        photosByIndex: {
          for (int i = 0; i < _activeTemplate.itens.length; i++)
            i: _photosForItem(i),
        },
        measuredValueByIndex: _measuredValueByIndex(),
        measuredUnitByIndex: _measuredUnitByIndex(),
        technicalNoteByIndex: _technicalNoteByIndex(),
        sampledLocationsByIndex: _sampledLocationsByIndex(),
        ncCompanyIdByIndex: _ncCompanyIdByItem,
        ncCompanyNameByIndex: _ncCompanyNameByItem,
        user: user,
      );
      _currentRecordId = record.id;

      if (!mounted) return;
      setState(() => _isLocked = false);
      _dirty = false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Inspeção reaberta')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao reabrir: $e')));
    }
  }

  Future<void> _tryFinish() async {
    if (!_canFinalizeInspection) {
      _permissionService.ensure(context, AppPermission.finalizeInspection);
      return;
    }
    final canProceed = await _ensureProfileCompleteForFvs();
    if (!canProceed) return;
    if (!mounted) return;

    if (_hasUnmarked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Marque todos os itens antes de finalizar.'),
        ),
      );
      return;
    }

    if (_nokWithoutObs.isNotEmpty) {
      final nums = _nokWithoutObs.map((i) => i + 1).join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Itens com prova/observação pendente: $nums')),
      );
      return;
    }

    if (_itemsMissingRequiredPhoto.isNotEmpty) {
      final nums = _itemsMissingRequiredPhoto.map((i) => i + 1).join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Adicione foto obrigatória nos itens $nums antes de finalizar.',
          ),
        ),
      );
      return;
    }

    try {
      final user = await _currentUserProfile();
      final draftKey = _getDraftKey();

      final hasNc = InspectionWorkflowService.instance.hasNc(
        InspectionWorkflowService.instance.composeItems(
          template: _activeTemplate,
          locationContext: widget.location['locationContext']?.toString(),
          statusByIndex: _statusByIndex(),
          obsByIndex: _obsByIndex(),
          photosByIndex: {
            for (int i = 0; i < _activeTemplate.itens.length; i++)
              i: _photosForItem(i),
          },
          measuredValueByIndex: _measuredValueByIndex(),
          measuredUnitByIndex: _measuredUnitByIndex(),
          technicalNoteByIndex: _technicalNoteByIndex(),
          sampledLocationsByIndex: _sampledLocationsByIndex(),
          ncCompanyIdByIndex: _ncCompanyIdByItem,
          ncCompanyNameByIndex: _ncCompanyNameByItem,
        ),
      );
      String? ncCompanyId;
      String? ncCompanyName;

      if (hasNc) {
        final selectedCompanyId = _firstNcCompanyIdFromForm();
        if (selectedCompanyId != null) {
          ncCompanyId = selectedCompanyId;
          ncCompanyName = _ncCompanyNameByItem.values
              .map((e) => e?.trim() ?? '')
              .firstWhere((name) => name.isNotEmpty, orElse: () => '');
          if (ncCompanyName.isEmpty) {
            ncCompanyName = null;
          }
        }
      }

      final record = await InspectionWorkflowService.instance.saveFinalized(
        location: widget.location,
        template: _activeTemplate,
        draftKey: draftKey,
        draftRecordId: _draftRecordId,
        currentRecordId: _currentRecordId,
        locationContext: widget.location['locationContext']?.toString(),
        inspectionElement: _selectedInspectionElement,
        operationalSheetId: _selectedOperationalSheetId,
        operationalSheetLabel: _selectedOperationalSheetLabel,
        statusByIndex: _statusByIndex(),
        obsByIndex: _obsByIndex(),
        photosByIndex: {
          for (int i = 0; i < _activeTemplate.itens.length; i++)
            i: _photosForItem(i),
        },
        measuredValueByIndex: _measuredValueByIndex(),
        measuredUnitByIndex: _measuredUnitByIndex(),
        technicalNoteByIndex: _technicalNoteByIndex(),
        sampledLocationsByIndex: _sampledLocationsByIndex(),
        ncCompanyIdByIndex: _ncCompanyIdByItem,
        ncCompanyNameByIndex: _ncCompanyNameByItem,
        user: user,
        ncCompanyId: ncCompanyId,
        ncCompanyName: ncCompanyName,
      );
      _currentRecordId = record.id;

      if (!mounted) return;
      if (widget.returnResultOnSaveFinish) {
        _dirty = false;
        Navigator.pop(context, {'action': 'finalizado', 'hasNc': hasNc});
        return;
      }
      _dirty = false;
      Navigator.pop(context, {'action': 'finalizado', 'hasNc': hasNc});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final torre = widget.location['torre'] ?? '';
    final apto = widget.location['apto'] ?? '';
    final localLabel =
        widget.location['localLabel'] ?? widget.location['ambiente'];
    final andar = widget.location['andar'] ?? 0;

    final localRef = widget.location['localRef']?.toString();
    final isRooftop =
        andar == 17 || localRef == 'ROOFTOP' || localRef == 'COBERTURA';
    final andarTexto = isRooftop
        ? 'Rooftop'
        : (andar == 0 ? 'Térreo' : '$andarº');
    final localHeader = localLabel?.toString().trim().isNotEmpty == true
        ? localLabel.toString().trim()
        : 'Apto $apto';
    final elementText = (_selectedInspectionElement ?? '').trim();
    final headerContext = [
      localHeader,
      andarTexto,
      if (elementText.isNotEmpty) elementText,
    ].join(' · ');
    final c = _counts;
    final totalItens = _activeTemplate.itens.length;
    final preenchidos = totalItens - (c['none'] ?? 0);
    final progresso = totalItens == 0 ? 0.0 : preenchidos / totalItens;

    final blockBackByDirty = !widget.readOnly && !_isLocked && _dirty;

    return PopScope(
      canPop: !blockBackByDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final leave = await _confirmExitWithoutSaving();
        if (!leave || !mounted) return;
        navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(headerContext)),

        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.black12),
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${FvsIconFormatter.getFvsIcon(_activeTemplate.nome)} '
                    '${_activeTemplate.nome.trim().isNotEmpty ? _activeTemplate.nome : 'FVS ${_activeTemplate.codigo}'}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _activeTemplate.nome,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    localHeader,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$torre • $andarTexto',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Elemento: ${elementText.isNotEmpty ? elementText : 'Não informado'}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if ((_selectedOperationalSheetLabel?.trim().isNotEmpty ??
                      false)) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Folha operacional: ${_selectedOperationalSheetLabel!.trim()}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            if (!widget.readOnly) ...[
              OutlinedButton.icon(
                onPressed: _isLocked ? null : _onPickFvsFromTop,
                icon: const Icon(Icons.checklist_outlined),
                label: Text(
                  '${FvsIconFormatter.getFvsIcon(_activeTemplate.nome)} '
                  '${_activeTemplate.nome.trim().isNotEmpty ? _activeTemplate.nome : 'FVS ${_activeTemplate.codigo}'}',
                ),
              ),
              const SizedBox(height: 12),
            ],

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black12),
                color: Colors.white,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'OK: ${c["ok"]}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'NOK: ${c["nok"]}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'NA/XO: ${c["xo"]}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Pend: ${c["none"]}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Progresso: $preenchidos/$totalItens',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${(progresso * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: progresso,
                    minHeight: 7,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            for (int i = 0; i < _activeTemplate.itens.length; i++)
              () {
                final proof = FvsProofCatalog.resolveForProject(
                  fvsCode: _activeTemplate.codigo,
                  itemIndex: i,
                  locationContext: widget.location['locationContext']
                      ?.toString(),
                  fallback: _activeTemplate.itens[i].proof,
                );
                return _ItemCard(
                  index: i,
                  item: _activeTemplate.itens[i],
                  proof: proof,
                  status: _status[i] ?? ItemStatus.none,
                  obsController: _obs(i),
                  measuredValue: (_measuredValueTextByItem[i] ?? '').trim(),
                  measuredUnit: (_measuredUnitByItem[i] ?? '').trim(),
                  technicalNote: (_technicalNoteByItem[i] ?? '').trim(),
                  sampledLocations:
                      _sampledLocationsByItem[i] ?? const <String>[],
                  photoPaths: _photoPathsByItem[i] ?? const [],
                  ncCompanyName: _ncCompanyNameByItem[i],
                  isLocked: _isLocked || widget.readOnly,
                  onTakePhoto: () async => await _addNcPhoto(i),
                  onRemovePhoto: (photo) async =>
                      await _removeNcPhoto(i, photo),
                  onPickNcCompany: () async => await _pickNcCompanyForItem(i),
                  onClearNcCompany: () => _clearNcCompanyForItem(i),
                  onMeasuredValueChanged: (value) {
                    _measuredValueTextByItem[i] = value;
                    _markDirty();
                  },
                  onMeasuredUnitChanged: (value) {
                    _measuredUnitByItem[i] = value;
                    _markDirty();
                  },
                  onTechnicalNoteChanged: (value) {
                    _technicalNoteByItem[i] = value;
                    _markDirty();
                  },
                  onSampledLocationsChanged: (value) {
                    _sampledLocationsByItem[i] = value
                        .split(',')
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toList(growable: false);
                    _markDirty();
                  },
                  onChange: (s) {
                    if (_isLocked || widget.readOnly) return;
                    () async {
                      final current = _status[i] ?? ItemStatus.none;

                      if (current == s) {
                        final oldPhotos = List<InspectionPhotoData>.from(
                          _photoPathsByItem[i] ?? const [],
                        );
                        setState(() {
                          _status[i] = ItemStatus.none;
                          _obs(i).text = '';
                          _photoPathsByItem[i] = [];
                          _measuredValueTextByItem.remove(i);
                          _measuredUnitByItem.remove(i);
                          _technicalNoteByItem.remove(i);
                          _sampledLocationsByItem.remove(i);
                          _ncCompanyIdByItem.remove(i);
                          _ncCompanyNameByItem.remove(i);
                          _dirty = true;
                        });
                        await _deletePhotoFiles(oldPhotos);
                        return;
                      }

                      if (s == ItemStatus.okAfterFix &&
                          _obs(i).text.trim().isEmpty) {
                        final note = await _askCorrectionNote();
                        if (note == null || note.trim().isEmpty) return;
                        _obs(i).text = note.trim();
                      }

                      final oldPhotos = List<InspectionPhotoData>.from(
                        _photoPathsByItem[i] ?? const [],
                      );
                      final proofType = InspectionItemResult.normalizeProofType(
                        proof.proofType,
                      );
                      final requiresPhotoForItem =
                          proof.requiresPhoto ||
                          proofType == InspectionItemResult.proofPhotoRequired;

                      setState(() {
                        _status[i] = s;
                        if (s == ItemStatus.ok) {
                          _obs(i).text = '';
                        }
                        if (s != ItemStatus.nok) {
                          if (!requiresPhotoForItem) {
                            _photoPathsByItem[i] = [];
                          }
                          _ncCompanyIdByItem.remove(i);
                          _ncCompanyNameByItem.remove(i);
                        }
                        _dirty = true;
                      });
                      if (s != ItemStatus.nok &&
                          !requiresPhotoForItem &&
                          oldPhotos.isNotEmpty) {
                        await _deletePhotoFiles(oldPhotos);
                      }
                      if (s != ItemStatus.nok &&
                          requiresPhotoForItem &&
                          _photosForItem(i).isEmpty) {
                        await _addNcPhoto(i);
                      }
                    }();
                  },
                );
              }(),

            // Espaço para não ficar por baixo do rodapé
            const SizedBox(height: 80),
          ],
        ),

        // ✅ NOVO: Rodapé fixo com 2 botões (A)
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: widget.readOnly
                ? const SizedBox.shrink()
                : _isLocked
                ? SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.lock_open),
                      label: const Text('Reabrir FVS'),
                      onPressed: () async => await _reopenInspection(),
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Salvar rascunho'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () async => await _saveDraft(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Finalizar'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: !_canFinalizeInspection
                              ? null
                              : () async => await _tryFinish(),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final int index;
  final FvsItem item;
  final FvsItemProofConfig proof;
  final ItemStatus status;
  final TextEditingController obsController;
  final String measuredValue;
  final String measuredUnit;
  final String technicalNote;
  final List<String> sampledLocations;
  final List<InspectionPhotoData> photoPaths;
  final String? ncCompanyName;
  final bool isLocked;
  final Future<void> Function() onTakePhoto;
  final Future<void> Function(InspectionPhotoData photo) onRemovePhoto;
  final Future<void> Function() onPickNcCompany;
  final VoidCallback onClearNcCompany;
  final ValueChanged<String> onMeasuredValueChanged;
  final ValueChanged<String> onMeasuredUnitChanged;
  final ValueChanged<String> onTechnicalNoteChanged;
  final ValueChanged<String> onSampledLocationsChanged;
  final ValueChanged<ItemStatus> onChange;

  const _ItemCard({
    required this.index,
    required this.item,
    required this.proof,
    required this.status,
    required this.obsController,
    required this.measuredValue,
    required this.measuredUnit,
    required this.technicalNote,
    required this.sampledLocations,
    required this.photoPaths,
    required this.ncCompanyName,
    required this.isLocked,
    required this.onTakePhoto,
    required this.onRemovePhoto,
    required this.onPickNcCompany,
    required this.onClearNcCompany,
    required this.onMeasuredValueChanged,
    required this.onMeasuredUnitChanged,
    required this.onTechnicalNoteChanged,
    required this.onSampledLocationsChanged,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final appColors = context.appColors;
    final isNok = status == ItemStatus.nok;
    final itemColors = _getFvsColors(appColors, status);
    final borderColor = isNok ? itemColors.border : scheme.outlineVariant;
    final bgColor = isNok ? itemColors.container : Theme.of(context).cardColor;
    final proofType = InspectionItemResult.normalizeProofType(proof.proofType);
    final requiresPhoto =
        proof.requiresPhoto ||
        proofType == InspectionItemResult.proofPhotoRequired;
    final requiresMeasurement =
        proofType == InspectionItemResult.proofMeasurement;
    final requiresTechnicalNote =
        proof.requiresTechnicalNote ||
        proofType == InspectionItemResult.proofTechnicalNote;
    final supportsSampling =
        proof.supportsSampling ||
        proofType == InspectionItemResult.proofSampledLocation;
    final toleranceMin = proof.measurementToleranceMin;
    final toleranceMax = proof.measurementToleranceMax;
    final measuredNumber = double.tryParse(measuredValue.replaceAll(',', '.'));
    final hasMeasured = measuredNumber != null;
    final inTolerance =
        hasMeasured &&
        (toleranceMin == null || measuredNumber >= toleranceMin) &&
        (toleranceMax == null || measuredNumber <= toleranceMax);
    final outTolerance =
        hasMeasured &&
        !inTolerance &&
        (toleranceMin != null || toleranceMax != null);

    Widget btn(String label, ItemStatus v, IconData icon) {
      final selected = status == v;
      final accentSet = _getFvsColors(appColors, v);
      final accent = accentSet.foreground;

      return Expanded(
        child: OutlinedButton.icon(
          onPressed: isLocked ? null : () => onChange(v),
          icon: Icon(icon, size: 18),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            backgroundColor: selected
                ? accentSet.container
                : Theme.of(context).cardColor,
            foregroundColor: selected ? accent : scheme.onSurface,
            side: BorderSide(
              color: selected ? accentSet.border : scheme.outlineVariant,
              width: selected ? 1.6 : 1,
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        color: bgColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${index + 1}. ${item.descricao}',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            item.dica,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (isNok) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: itemColors.container,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'NOK marcado',
                style: TextStyle(
                  color: itemColors.foreground,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              btn('OK', ItemStatus.ok, Icons.check),
              const SizedBox(width: 8),
              btn('NOK', ItemStatus.nok, Icons.close),
              const SizedBox(width: 8),
              btn('NA/XO', ItemStatus.okAfterFix, Icons.refresh),
            ],
          ),
          if (requiresMeasurement) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: measuredValue,
                    enabled: !isLocked,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Valor medido (obrigatório)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: onMeasuredValueChanged,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 96,
                  child: TextFormField(
                    initialValue: measuredUnit.isNotEmpty
                        ? measuredUnit
                        : (proof.measurementUnit ?? ''),
                    enabled: !isLocked,
                    decoration: const InputDecoration(
                      labelText: 'Unid.',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: onMeasuredUnitChanged,
                  ),
                ),
              ],
            ),
            if (toleranceMin != null || toleranceMax != null) ...[
              const SizedBox(height: 6),
              Text(
                'Tolerância: ${toleranceMin?.toStringAsFixed(2) ?? '—'} a ${toleranceMax?.toStringAsFixed(2) ?? '—'}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              if (hasMeasured)
                Text(
                  outTolerance ? 'Fora da tolerância' : 'Dentro da tolerância',
                  style: TextStyle(
                    color: outTolerance
                        ? Colors.red.shade700
                        : Colors.green.shade700,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
            ],
          ],
          if (requiresTechnicalNote) ...[
            const SizedBox(height: 10),
            TextFormField(
              initialValue: technicalNote,
              enabled: !isLocked,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Nota técnica (obrigatória)',
                border: OutlineInputBorder(),
              ),
              onChanged: onTechnicalNoteChanged,
            ),
          ],
          if (supportsSampling) ...[
            const SizedBox(height: 10),
            TextFormField(
              initialValue: sampledLocations.join(', '),
              enabled: !isLocked,
              decoration: const InputDecoration(
                labelText: 'Locais amostrados (base futura)',
                hintText: 'Ex.: Apto 101, Apto 203',
                border: OutlineInputBorder(),
              ),
              onChanged: onSampledLocationsChanged,
            ),
          ],
          if (status == ItemStatus.nok || status == ItemStatus.okAfterFix) ...[
            const SizedBox(height: 10),
            TextField(
              controller: obsController,
              readOnly: isLocked,
              enabled: !isLocked,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: status == ItemStatus.okAfterFix
                    ? 'Correção (obrigatório no XO)'
                    : 'Observação (obrigatório no X)',
                border: const OutlineInputBorder(),
              ),
            ),
            if (status == ItemStatus.nok) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      (ncCompanyName ?? '').trim().isEmpty
                          ? 'Empreiteiro responsável: não definido'
                          : 'Empreiteiro responsável: ${ncCompanyName!.trim()}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: isLocked
                        ? null
                        : () async => await onPickNcCompany(),
                    child: const Text('Definir'),
                  ),
                  if ((ncCompanyName ?? '').trim().isNotEmpty)
                    TextButton(
                      onPressed: isLocked ? null : onClearNcCompany,
                      child: const Text('Remover'),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: isLocked || photoPaths.length >= 5
                      ? null
                      : () async => await onTakePhoto(),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text('Tirar foto (${photoPaths.length}/5)'),
                ),
              ),
              if (photoPaths.isNotEmpty) ...[
                const SizedBox(height: 8),
                PhotoViewerGrid(
                  photos: photoPaths,
                  onDeleted: isLocked
                      ? (_) async {}
                      : (photo) async => await onRemovePhoto(photo),
                ),
              ],
            ],
          ],
          if (requiresPhoto && status != ItemStatus.nok) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: isLocked || photoPaths.length >= 5
                    ? null
                    : () async => await onTakePhoto(),
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text('Foto de evidência (${photoPaths.length}/5)'),
              ),
            ),
            if (photoPaths.isNotEmpty) ...[
              const SizedBox(height: 8),
              PhotoViewerGrid(
                photos: photoPaths,
                onDeleted: isLocked
                    ? (_) async {}
                    : (photo) async => await onRemovePhoto(photo),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Foto obrigatória pendente.',
                  style: TextStyle(
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

({Color container, Color foreground, Color border}) _getFvsColors(
  AppColors colors,
  ItemStatus status,
) {
  switch (status) {
    case ItemStatus.ok:
      return (
        container: colors.fvsOkContainer,
        foreground: colors.fvsOkForeground,
        border: colors.fvsOkBorder,
      );
    case ItemStatus.nok:
      return (
        container: colors.fvsNokContainer,
        foreground: colors.fvsNokForeground,
        border: colors.fvsNokBorder,
      );
    case ItemStatus.okAfterFix:
      return (
        container: colors.fvsXoContainer,
        foreground: colors.fvsXoForeground,
        border: colors.fvsXoBorder,
      );
    case ItemStatus.none:
      return (
        container: colors.fvsNoneContainer,
        foreground: colors.fvsNoneForeground,
        border: colors.fvsNoneBorder,
      );
  }
}
