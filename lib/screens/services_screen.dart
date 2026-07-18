import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../data/fvs_catalog.dart';
import '../data/fvs_location_catalog.dart';
import '../data/inspection_element_catalog.dart';
import '../models/company_record.dart';
import '../models/inspection_record.dart';
import '../models/service_record.dart';
import '../services/permission_service.dart';
import '../services/project_context_service.dart';
import '../services/project_settings_service.dart';
import '../services/sync_orchestrator.dart';
import '../theme/app_colors.dart';
import '../utils/project_scope.dart';
import 'company_form_screen.dart';
import 'inspection_screen.dart';
import 'select_location_screen.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  String _tab = 'em_andamento';
  final ProjectContextService _projectContext = ProjectContextService.instance;
  final PermissionService _permissionService = PermissionService.instance;

  bool get _canEditRegistry =>
      _permissionService.has(AppPermission.editRegistry);

  void _showNoPermissionMessage() {
    _permissionService.ensure(context, AppPermission.editRegistry);
  }

  @override
  void initState() {
    super.initState();
    _seedCompaniesIfNeeded();
  }

  Future<void> _seedCompaniesIfNeeded() async {
    final box = Hive.box<CompanyRecord>('companies');
    if (box.isNotEmpty) return;
    final projectId = await ProjectContextService.instance
        .getCurrentProjectId();

    final seeds = [
      ('MSX', 'elétrica'),
      ('MSantos', 'hidráulica'),
      ('EJ', 'carpintaria'),
      ('JS', 'bloqueiro'),
      ('JSena', 'piso porcelanato'),
      ('Valderi', 'pedreiro'),
      ('Joilson', 'pedreiro'),
    ];

    final now = DateTime.now();
    for (final seed in seeds) {
      final nome = seed.$1;
      final id = 'company:$projectId:${_companyIdFromName(nome)}';
      final record = CompanyRecord(
        id: id,
        nome: nome,
        especialidade: seed.$2,
        cnpj: null,
        phone: null,
        createdAt: now,
        updatedAt: now,
        deleted: false,
        pendingSync: true,
        deletedAt: null,
        projectId: projectId,
      );
      await box.put(id, record);
      await SyncOrchestrator.instance.refreshPendingSnapshot();
    }
  }

  String _companyIdFromName(String nome) {
    final base = nome
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');
    return base.isEmpty
        ? DateTime.now().microsecondsSinceEpoch.toString()
        : base;
  }

  String _serviceScopedId({
    required String projectId,
    required String companyId,
    required String torre,
    required int andar,
    required String localRef,
  }) {
    return 'service:$projectId:$companyId:$torre:$andar:$localRef';
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'em_andamento':
        return 'Em andamento';
      case 'aguardando_inspecao':
        return 'Aguardando inspeção';
      case 'pendente':
        return 'Pendente';
      case 'concluido':
        return 'Concluído';
      default:
        return status;
    }
  }

  Color _statusColor(BuildContext context, String status) {
    final colors = context.appColors;
    if (status == 'em_andamento') return colors.warning;
    if (status == 'pendente') return colors.danger;
    if (status == 'concluido') return colors.success;
    return colors.selected;
  }

  Future<CompanyRecord?> _showCompanyForm({CompanyRecord? initial}) async {
    if (!_canEditRegistry) {
      _showNoPermissionMessage();
      return null;
    }
    final box = Hive.box<CompanyRecord>('companies');
    return showCompanyFormDialog(context: context, box: box, initial: initial);
  }

  Future<CompanyRecord?> _pickCompany() async {
    final box = Hive.box<CompanyRecord>('companies');
    final currentProjectId = _projectContext.currentProjectIdSync;

    return showModalBottomSheet<CompanyRecord?>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final companies =
                filterRecordsByProjectScope(
                  box.values,
                  currentProjectId: currentProjectId,
                  projectId: (c) => c.projectId,
                ).toList()..sort(
                  (a, b) =>
                      a.nome.toLowerCase().compareTo(b.nome.toLowerCase()),
                );
            final filtered = companies.where((c) {
              if (query.trim().isEmpty) return true;
              final q = query.toLowerCase();
              return c.nome.toLowerCase().contains(q) ||
                  c.especialidade.toLowerCase().contains(q);
            }).toList();

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.72,
                  child: Column(
                    children: [
                      const ListTile(
                        title: Text(
                          'Escolher empresa',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: TextField(
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'Buscar por nome ou especialidade',
                          ),
                          onChanged: (v) => setSheetState(() => query = v),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () async {
                              final created = await _showCompanyForm();
                              if (created == null || !context.mounted) return;
                              setSheetState(() {});
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Nova empresa'),
                          ),
                        ),
                      ),
                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(
                                child: Text('Nenhuma empresa encontrada.'),
                              )
                            : ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, index) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final c = filtered[index];
                                  return ListTile(
                                    title: Text(c.nome),
                                    subtitle: Text(c.especialidade),
                                    onTap: () => Navigator.pop(context, c),
                                    trailing: IconButton(
                                      tooltip: 'Editar empresa',
                                      icon: const Icon(Icons.edit_outlined),
                                      onPressed: () async {
                                        await _showCompanyForm(initial: c);
                                        if (!context.mounted) return;
                                        setSheetState(() {});
                                      },
                                    ),
                                  );
                                },
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

  Future<void> _iniciarServico() async {
    if (!_canEditRegistry) {
      _showNoPermissionMessage();
      return;
    }
    final selectedCompany = await _pickCompany();
    if (!mounted || selectedCompany == null) return;

    final settings = ProjectSettingsService.instance.currentProjectSettingsSync;
    String locationContext = '';

    if (settings != null && settings.operationalSheets.isNotEmpty) {
      final firstOps = settings.operationalSheets.first;
      if (firstOps.fvsCode.isNotEmpty) {
        final template = FvsCatalog.all
            .where((t) => t.codigo == firstOps.fvsCode)
            .firstOrNull;
        if (template != null) {
          final profile = FvsLocationCatalog.profileForTemplate(template);
          locationContext = profile.defaultContextId;
          if (locationContext.isEmpty) {
            locationContext =
                settings.fvsContextOverrides[template.codigo]?.toString() ?? '';
          }
        }
      }
    }

    final location = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => SelectLocationScreen(
          title: 'Serviços – Escolher Local',
          autoOpenFvsOnMap: false,
          locationContext: locationContext,
        ),
      ),
    );

    if (!mounted || location == null) return;

    final obra = (location['obra'] ?? '').toString();
    final torre = (location['torre'] ?? '').toString();
    final andar = location['andar'] is int ? location['andar'] as int : 0;
    final localRef = (location['localRef'] ?? location['apto'] ?? '')
        .toString();
    final localLabel =
        (location['localLabel'] ??
                location['ambiente'] ??
                'Apto ${location['apto'] ?? ''}')
            .toString();
    final projectId = await ProjectContextService.instance
        .getCurrentProjectId();

    final id = _serviceScopedId(
      projectId: projectId,
      companyId: selectedCompany.id,
      torre: torre,
      andar: andar,
      localRef: localRef,
    );
    final legacyId =
        'service:$obra:${selectedCompany.id}:$torre:$andar:$localRef';
    final box = Hive.box<ServiceRecord>('services');
    final existing = box.get(id) ?? box.get(legacyId);

    if (existing != null && existing.status != 'concluido') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Já existe serviço ativo para este empreiteiro neste local.',
          ),
        ),
      );
      return;
    }

    final now = DateTime.now();
    final record = ServiceRecord(
      id: id,
      obra: obra,
      torre: torre,
      andar: andar,
      localRef: localRef,
      localLabel: localLabel,
      empresaId: selectedCompany.id,
      empresaNome: selectedCompany.nome,
      servicoCodigo: '',
      servicoNome: '',
      status: 'em_andamento',
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      deleted: false,
      pendingSync: true,
      deletedAt: null,
      projectId: projectId,
    );

    await box.put(id, record);
    await SyncOrchestrator.instance.refreshPendingSnapshot();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Serviço iniciado com sucesso.')),
    );
  }

  Future<void> _finalizar(ServiceRecord rec) async {
    if (!_canEditRegistry) {
      _showNoPermissionMessage();
      return;
    }
    final box = Hive.box<ServiceRecord>('services');
    final updated = rec.copyWith(
      status: 'aguardando_inspecao',
      updatedAt: DateTime.now(),
      pendingSync: true,
      deleted: false,
      deletedAt: null,
    );
    await box.put(updated.id, updated);
    await SyncOrchestrator.instance.refreshPendingSnapshot();
  }

  Future<void> _updateStatus(ServiceRecord rec, String status) async {
    if (!_canEditRegistry) {
      _showNoPermissionMessage();
      return;
    }
    final box = Hive.box<ServiceRecord>('services');
    final updated = rec.copyWith(
      status: status,
      updatedAt: DateTime.now(),
      pendingSync: true,
      deleted: false,
      deletedAt: null,
    );
    await box.put(updated.id, updated);
    await SyncOrchestrator.instance.refreshPendingSnapshot();
  }

  Future<FvsTemplate?> _pickFvsForInspection() async {
    final all = FvsCatalog.all.toList()
      ..sort((a, b) => a.codigo.compareTo(b.codigo));
    String? selected;
    return showDialog<FvsTemplate?>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Qual FVS abrir?'),
              content: DropdownButtonFormField<String>(
                initialValue: selected,
                isExpanded: true,
                items: all
                    .map(
                      (f) => DropdownMenuItem(
                        value: f.codigo,
                        child: Text('${f.codigo} — ${f.nome}'),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setDialogState(() => selected = v),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: selected == null
                      ? null
                      : () => Navigator.pop(
                          context,
                          all.firstWhere((f) => f.codigo == selected),
                        ),
                  child: const Text('Abrir FVS'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openInspectionFromService(ServiceRecord rec) async {
    final template = await _pickFvsForInspection();
    if (!mounted || template == null) return;

    final inspectionsBox = Hive.box<InspectionRecord>('inspections');
    final activeProjectId = _projectContext.currentProjectIdSync;
    final requiresElement = InspectionElementCatalog.requiresElement(template);
    InspectionRecord? latest;
    for (final r in inspectionsBox.values) {
      if (r.deleted) continue;
      if (!matchesActiveProject(
        activeProjectId: activeProjectId,
        recordProjectId: r.projectId,
        recordObra: r.obra,
      )) {
        continue;
      }
      final same =
          r.torre == rec.torre &&
          r.andar == rec.andar &&
          r.localRef == rec.localRef &&
          r.fvsCodigo == template.codigo;
      final compatibleElement =
          !requiresElement || r.normalizedInspectionElement.isEmpty;
      if (!same || !compatibleElement) continue;
      if (latest == null || r.updatedAt.isAfter(latest.updatedAt)) latest = r;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InspectionScreen(
          location: {
            'obra': rec.obra,
            'projectId': rec.projectId,
            'torre': rec.torre,
            'andar': rec.andar,
            'apto': rec.localLabel,
            'localRef': rec.localRef,
            'localLabel': rec.localLabel,
            'element': '',
          },
          template: template,
          inspectionId: latest?.id,
          returnResultOnSaveFinish: true,
        ),
      ),
    );

    if (!mounted || result is! Map) return;
    final hasNc = result['hasNc'] == true;

    final servicesBox = Hive.box<ServiceRecord>('services');
    final current = servicesBox.get(rec.id);
    if (current == null) return;

    final status = hasNc ? 'em_andamento' : 'concluido';
    await servicesBox.put(
      current.id,
      current.copyWith(
        servicoCodigo: template.codigo,
        servicoNome: template.nome,
        status: status,
        updatedAt: DateTime.now(),
        pendingSync: true,
        deleted: false,
        deletedAt: null,
      ),
    );
    final synced = servicesBox.get(current.id);
    if (synced != null) {
      await SyncOrchestrator.instance.refreshPendingSnapshot();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final box = Hive.box<ServiceRecord>('services');

    return Scaffold(
      appBar: AppBar(title: const Text('Serviços')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _canEditRegistry
            ? _iniciarServico
            : _showNoPermissionMessage,
        icon: const Icon(Icons.add_task),
        label: const Text('Iniciar serviço'),
      ),
      body: ValueListenableBuilder<Box<ServiceRecord>>(
        valueListenable: box.listenable(),
        builder: (context, value, _) {
          final currentProjectId = _projectContext.currentProjectIdSync;
          final all = filterRecordsByProjectScope(
            value.values.where((e) => !e.deleted),
            currentProjectId: currentProjectId,
            projectId: (e) => e.projectId,
            obra: (e) => e.obra,
          ).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          final openCount = all.where((e) => e.status == 'em_andamento').length;
          final waitCount = all
              .where((e) => e.status == 'aguardando_inspecao')
              .length;
          final pendCount = all.where((e) => e.status == 'pendente').length;
          final doneCount = all.where((e) => e.status == 'concluido').length;
          final records = all.where((e) => e.status == _tab).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: Text('Em andamento ($openCount)'),
                        selected: _tab == 'em_andamento',
                        onSelected: (_) =>
                            setState(() => _tab = 'em_andamento'),
                        showCheckmark: false,
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text('Aguardando inspeção ($waitCount)'),
                        selected: _tab == 'aguardando_inspecao',
                        onSelected: (_) =>
                            setState(() => _tab = 'aguardando_inspecao'),
                        showCheckmark: false,
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text('Pendente ($pendCount)'),
                        selected: _tab == 'pendente',
                        onSelected: (_) => setState(() => _tab = 'pendente'),
                        showCheckmark: false,
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text('Concluído ($doneCount)'),
                        selected: _tab == 'concluido',
                        onSelected: (_) => setState(() => _tab = 'concluido'),
                        showCheckmark: false,
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: records.isEmpty
                    ? Center(
                        child: Text(
                          'Nenhum serviço em ${_statusLabel(_tab).toLowerCase()}.',
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: records.length,
                        separatorBuilder: (_, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final r = records[index];
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${r.torre} • ${r.localLabel}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    r.servicoCodigo.isEmpty
                                        ? 'FVS: a definir na inspeção'
                                        : '${r.servicoCodigo} ${r.servicoNome}',
                                  ),
                                  const SizedBox(height: 2),
                                  Text('Empresa: ${r.empresaNome}'),
                                  const SizedBox(height: 8),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _statusColor(
                                            context,
                                            r.status,
                                          ).withValues(alpha: 0.18),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: _statusColor(
                                              context,
                                              r.status,
                                            ).withValues(alpha: 0.58),
                                          ),
                                        ),
                                        child: Text(
                                          _statusLabel(r.status),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: _statusColor(
                                              context,
                                              r.status,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Wrap(
                                          alignment: WrapAlignment.end,
                                          spacing: 4,
                                          runSpacing: 2,
                                          children: [
                                            if (r.status == 'em_andamento')
                                              TextButton.icon(
                                                onPressed: _canEditRegistry
                                                    ? () => _finalizar(r)
                                                    : _showNoPermissionMessage,
                                                icon: Icon(
                                                  Icons.check_circle_outline,
                                                  color: appColors.success,
                                                ),
                                                label: const Text(
                                                  'Finalizar serviço',
                                                ),
                                              ),
                                            if (r.status ==
                                                'aguardando_inspecao')
                                              TextButton.icon(
                                                onPressed: () =>
                                                    _openInspectionFromService(
                                                      r,
                                                    ),
                                                icon: Icon(
                                                  Icons
                                                      .assignment_turned_in_outlined,
                                                  color: appColors.selected,
                                                ),
                                                label: const Text('Abrir FVS'),
                                              ),
                                            if (r.status == 'em_andamento')
                                              TextButton.icon(
                                                onPressed: _canEditRegistry
                                                    ? () => _updateStatus(
                                                        r,
                                                        'pendente',
                                                      )
                                                    : _showNoPermissionMessage,
                                                icon: Icon(
                                                  Icons.pause_circle_outline,
                                                  color: appColors.warning,
                                                ),
                                                label: const Text(
                                                  'Marcar pendente',
                                                ),
                                              ),
                                            if (r.status == 'pendente')
                                              TextButton.icon(
                                                onPressed: _canEditRegistry
                                                    ? () => _updateStatus(
                                                        r,
                                                        'em_andamento',
                                                      )
                                                    : _showNoPermissionMessage,
                                                icon: Icon(
                                                  Icons.play_circle_outline,
                                                  color: appColors.selected,
                                                ),
                                                label: const Text('Retomar'),
                                              ),
                                            if (r.status == 'pendente')
                                              TextButton.icon(
                                                onPressed: _canEditRegistry
                                                    ? () => _updateStatus(
                                                        r,
                                                        'concluido',
                                                      )
                                                    : _showNoPermissionMessage,
                                                icon: Icon(
                                                  Icons.task_alt_outlined,
                                                  color: appColors.success,
                                                ),
                                                label: const Text('Concluir'),
                                              ),
                                            if (r.status == 'concluido')
                                              TextButton.icon(
                                                onPressed: _canEditRegistry
                                                    ? () => _updateStatus(
                                                        r,
                                                        'em_andamento',
                                                      )
                                                    : _showNoPermissionMessage,
                                                icon: Icon(
                                                  Icons.refresh_outlined,
                                                  color: appColors.selected,
                                                ),
                                                label: const Text('Reabrir'),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
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
    );
  }
}
