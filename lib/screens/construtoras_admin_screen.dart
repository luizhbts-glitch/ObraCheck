import 'package:flutter/material.dart';

import '../models/construtora_record.dart';
import '../services/construtora_admin_service.dart';
import '../services/permission_service.dart';
import '../services/project_context_service.dart';
import '../services/project_members_service.dart';

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
  Map<String, String> _diretorEmails = const {};

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

    final allDiretorUids = <String>{};
    for (final org in construtoras) {
      for (final m in _service.diretoresOfOrg(org.id)) {
        allDiretorUids.add(m.userId);
      }
    }
    final emails =
        await ProjectMembersService.instance.userEmailByUidMap(allDiretorUids);

    if (!mounted) return;
    setState(() {
      _construtoras = construtoras;
      _diretorEmails = emails;
      _loading = false;
    });
  }

  Future<void> _createConstrutora() async {
    if (!_permission.ensure(context, AppPermission.manageConstrutoras)) return;

    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nova construtora'),
        content: TextField(
          controller: controller,
          autofocus: true,
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

  Future<void> _editProjectLinks(ConstrutoraRecord org) async {
    final allProjects = ProjectContextService.instance.allProjects();

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
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
                            value: project.orgId.trim() == org.id,
                            onChanged: (checked) async {
                              final otherOrg = project.orgId.trim().isNotEmpty &&
                                  project.orgId.trim() != org.id;
                              if (checked == true && otherOrg) {
                                ScaffoldMessenger.of(context).showSnackBar(
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
                            },
                          ),
                      ],
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fechar'),
              ),
            ],
          );
        },
      ),
    );
    await _reload();
  }

  Future<void> _addDiretor(ConstrutoraRecord org) async {
    if (!_permission.ensure(context, AppPermission.manageConstrutoras)) return;

    final controller = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
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
    final result =
        await _service.addDiretorByEmail(orgId: org.id, email: email);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(result.message)));
    await _reload();
  }

  Widget _buildOrgCard(ConstrutoraRecord org) {
    final projects = _service.projectsOfOrg(org.id);
    final diretores = _service.diretoresOfOrg(org.id);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ExpansionTile(
        leading: const Icon(Icons.business),
        title: Text(org.name),
        subtitle: Text(
          '${projects.length} obra(s) · ${diretores.where((d) => d.isActive).length} diretor(es)',
        ),
        children: [
          ListTile(
            dense: true,
            leading: const Icon(Icons.apartment),
            title: const Text('Obras vinculadas'),
            subtitle: Text(
              projects.isEmpty
                  ? 'Nenhuma obra vinculada'
                  : projects.map((p) => p.name).join(', '),
            ),
            trailing: TextButton(
              onPressed: () => _editProjectLinks(org),
              child: const Text('Editar'),
            ),
          ),
          const Divider(height: 1),
          for (final diretor in diretores)
            SwitchListTile(
              dense: true,
              secondary: const Icon(Icons.badge_outlined),
              title: Text(_diretorEmails[diretor.userId] ?? diretor.userId),
              subtitle: Text(diretor.isActive ? 'Diretor ativo' : 'Inativo'),
              value: diretor.isActive,
              onChanged: (value) async {
                await _service.setDiretorActive(
                  membership: diretor,
                  isActive: value,
                );
                await _reload();
              },
            ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _addDiretor(org),
                icon: const Icon(Icons.person_add_alt),
                label: const Text('Adicionar diretor'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_canManage) {
      return Scaffold(
        appBar: AppBar(title: const Text('Construtoras')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Apenas o administrador do sistema acessa esta área.',
              textAlign: TextAlign.center,
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
          : _construtoras.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Nenhuma construtora cadastrada.\nCrie a primeira para agrupar as obras.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 96, top: 8),
                  children: [
                    for (final org in _construtoras) _buildOrgCard(org),
                  ],
                ),
    );
  }
}
