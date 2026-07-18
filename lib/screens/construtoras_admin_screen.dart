import 'package:flutter/material.dart';

import '../models/construtora_record.dart';
import '../services/construtora_admin_service.dart';
import '../services/permission_service.dart';
import '../services/project_context_service.dart';
import '../services/project_members_service.dart';
import '../theme/app_colors.dart';
import '../widgets/admin_ui.dart';

/// Tela do administrador global: cadastra construtoras, vincula obras
/// e gerencia diretores. Invisível/bloqueada para os demais papéis.
class ConstrutorasAdminScreen extends StatefulWidget {
  const ConstrutorasAdminScreen({super.key});

  @override
  State<ConstrutorasAdminScreen> createState() =>
      _ConstrutorasAdminScreenState();
}

class _ConstrutorasAdminScreenState extends State<ConstrutorasAdminScreen> {
  final PermissionService _permission = PermissionService.instance;
  final ConstrutoraAdminService _service = ConstrutoraAdminService.instance;

  bool _loading = false;
  List<ConstrutoraRecord> _construtoras = const [];

  bool get _canManage =>
      PermissionService.instance.has(AppPermission.manageConstrutoras);

  @override
  void initState() {
    super.initState();
    _reload(remote: true);
  }

  Future<void> _reload({bool remote = false}) async {
    if (mounted) setState(() => _loading = true);
    if (remote) {
      await _service.refreshFromRemote();
    }
    final construtoras = _service.allConstrutoras();
    if (!mounted) return;
    setState(() {
      _construtoras = construtoras;
      _loading = false;
    });
  }

  Future<void> _createConstrutora() async {
    if (!_permission.ensure(context, AppPermission.manageConstrutoras)) return;

    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.add_business_outlined),
        title: const Text('Nova construtora'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nome da construtora',
            hintText: 'Ex.: Construtora Alfa',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Criar'),
          ),
        ],
      ),
    );

    if (name == null || name.trim().isEmpty) return;
    await _service.createConstrutora(name);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;

    if (!_canManage) {
      return Scaffold(
        appBar: AppBar(title: const Text('Construtoras')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: EmptyStateHint(
              icon: Icons.lock_outline,
              message: 'Apenas o administrador do sistema acessa esta área.',
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Construtoras'),
        actions: [
          IconButton(
            tooltip: 'Atualizar da nuvem',
            onPressed: _loading ? null : () => _reload(remote: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createConstrutora,
        icon: const Icon(Icons.add_business),
        label: const Text('Nova construtora'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _reload(remote: true),
              child: _construtoras.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        EmptyStateHint(
                          icon: Icons.business_outlined,
                          message:
                              'Nenhuma construtora cadastrada.\nCrie a primeira para agrupar as obras.',
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                      itemCount: _construtoras.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final org = _construtoras[index];
                        final projects = _service.projectsOfOrg(org.id);
                        final diretoresAtivos = _service
                            .diretoresOfOrg(org.id)
                            .where((d) => d.isActive)
                            .length;

                        return Card(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ConstrutoraDetailScreen(orgId: org.id),
                                ),
                              );
                              await _reload();
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  InitialsAvatar(
                                    label: org.name,
                                    background:
                                        appColors.selected.withValues(alpha: 0.14),
                                    foreground: appColors.selected,
                                    radius: 22,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          org.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15.5,
                                            color: appColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: [
                                            StatusBadge(
                                              label: '${projects.length} obra${projects.length == 1 ? '' : 's'}',
                                              color: appColors.selected,
                                              icon: Icons.apartment_outlined,
                                            ),
                                            StatusBadge(
                                              label: '$diretoresAtivos diretor${diretoresAtivos == 1 ? '' : 'es'}',
                                              color: appColors.success,
                                              icon: Icons.badge_outlined,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    color: appColors.textSecondary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

/// Detalhe de uma construtora: obras vinculadas + diretores.
class ConstrutoraDetailScreen extends StatefulWidget {
  const ConstrutoraDetailScreen({super.key, required this.orgId});

  final String orgId;

  @override
  State<ConstrutoraDetailScreen> createState() =>
      _ConstrutoraDetailScreenState();
}

class _ConstrutoraDetailScreenState extends State<ConstrutoraDetailScreen> {
  final ConstrutoraAdminService _service = ConstrutoraAdminService.instance;

  bool _loadingEmails = true;
  Map<String, String> _diretorEmails = const {};

  ConstrutoraRecord? get _org => _service
      .allConstrutoras()
      .cast<ConstrutoraRecord?>()
      .firstWhere((c) => c?.id == widget.orgId, orElse: () => null);

  @override
  void initState() {
    super.initState();
    _loadEmails();
  }

  Future<void> _loadEmails() async {
    final diretores = _service.diretoresOfOrg(widget.orgId);
    final emails = await ProjectMembersService.instance
        .userEmailByUidMap(diretores.map((d) => d.userId));
    if (!mounted) return;
    setState(() {
      _diretorEmails = emails;
      _loadingEmails = false;
    });
  }

  Future<void> _editProjectLinks(ConstrutoraRecord org) async {
    final appColors = context.appColors;
    final allProjects = ProjectContextService.instance.allProjects();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: Text('Obras de ${org.name}'),
            content: SizedBox(
              width: double.maxFinite,
              child: allProjects.isEmpty
                  ? const Text('Nenhuma obra cadastrada ainda.')
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        for (final project in allProjects)
                          CheckboxListTile(
                            title: Text(project.name),
                            subtitle: Text(project.code),
                            activeColor: appColors.selected,
                            value: project.orgId.trim() == org.id,
                            onChanged: (checked) async {
                              final otherOrg = project.orgId.trim().isNotEmpty &&
                                  project.orgId.trim() != org.id;
                              if (checked == true && otherOrg) {
                                ScaffoldMessenger.of(dialogContext).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Esta obra já pertence a outra construtora. Desvincule lá primeiro.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              await _service.setProjectOrg(
                                projectId: project.id,
                                orgId: checked == true ? org.id : '',
                              );
                              setDialogState(() {});
                              if (mounted) setState(() {});
                            },
                          ),
                      ],
                    ),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Concluído'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addDiretor(ConstrutoraRecord org) async {
    final controller = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.person_add_alt_outlined),
        title: Text('Novo diretor — ${org.name}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email da conta do diretor',
            hintText: 'A pessoa precisa já ter conta no app',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Vincular'),
          ),
        ],
      ),
    );

    if (email == null || email.trim().isEmpty) return;
    final result = await _service.addDiretorByEmail(orgId: org.id, email: email);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(result.message)));
    await _loadEmails();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final org = _org;

    if (org == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Construtora')),
        body: const Center(child: Text('Construtora não encontrada.')),
      );
    }

    final projects = _service.projectsOfOrg(org.id);
    final diretores = _service.diretoresOfOrg(org.id);

    return Scaffold(
      appBar: AppBar(title: Text(org.name)),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(
                    icon: Icons.apartment_outlined,
                    title: 'Obras vinculadas',
                    color: appColors.selected,
                    trailing: StatusBadge(
                      label: '${projects.length}',
                      color: appColors.selected,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (projects.isEmpty)
                    EmptyStateHint(
                      icon: Icons.apartment_outlined,
                      message: 'Nenhuma obra vinculada ainda.',
                    )
                  else
                    ...projects.map(
                      (p) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_city_outlined,
                              size: 18,
                              color: appColors.textSecondary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: appColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    p.code,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: appColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: () => _editProjectLinks(org),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Gerenciar vínculos'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(
                    icon: Icons.badge_outlined,
                    title: 'Diretores',
                    color: appColors.success,
                    trailing: StatusBadge(
                      label: '${diretores.where((d) => d.isActive).length} ativo(s)',
                      color: appColors.success,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_loadingEmails)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  else if (diretores.isEmpty)
                    EmptyStateHint(
                      icon: Icons.person_search_outlined,
                      message: 'Nenhum diretor vinculado ainda.',
                    )
                  else
                    ...diretores.map((diretor) {
                      final label = _diretorEmails[diretor.userId] ?? diretor.userId;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            InitialsAvatar(
                              label: label,
                              background: appColors.success.withValues(alpha: 0.14),
                              foreground: appColors.success,
                              radius: 16,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: appColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Switch(
                              value: diretor.isActive,
                              onChanged: (value) async {
                                await _service.setDiretorActive(
                                  membership: diretor,
                                  isActive: value,
                                );
                                setState(() {});
                              },
                            ),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: () => _addDiretor(org),
                      icon: const Icon(Icons.person_add_alt, size: 16),
                      label: const Text('Adicionar diretor'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
