import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/project_invite_record.dart';
import '../models/project_access_code_record.dart';
import '../models/user_project_membership.dart';
import '../services/permission_service.dart';
import '../services/project_context_service.dart';
import '../services/project_members_service.dart';

class ProjectMembersScreen extends StatefulWidget {
  const ProjectMembersScreen({super.key});

  @override
  State<ProjectMembersScreen> createState() => _ProjectMembersScreenState();
}

class _ProjectMembersScreenState extends State<ProjectMembersScreen> {
  String _role = UserProjectMembership.roleViewer;
  DateTime _expiresAt = DateTime.now().add(const Duration(days: 7));
  int _maxUses = 1;
  bool _loading = false;
  bool _submitting = false;

  List<UserProjectMembership> _memberships = const [];
  Map<String, String> _memberNames = const {};
  Map<String, String> _memberEmails = const {};
  List<ProjectInviteRecord> _pendingInvites = const [];
  List<ProjectAccessCodeRecord> _activeCodes = const [];

  final PermissionService _permission = PermissionService.instance;

  bool get _canManage => ProjectContextService.instance.canManageUsersSync;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _reload() async {
    if (mounted) setState(() => _loading = true);

    final memberships = ProjectMembersService.instance.membershipsForCurrentProject();
    final pendingInvites = ProjectMembersService.instance.pendingInvitesForCurrentProject();
    final activeCodes = ProjectMembersService.instance.activeAccessCodesForCurrentProject();
    final names = await ProjectMembersService.instance
        .userNameByUidMap(memberships.map((m) => m.userId));
    final emails = await ProjectMembersService.instance
        .userEmailByUidMap(memberships.map((m) => m.userId));

    if (!mounted) return;
    setState(() {
      _memberships = memberships;
      _pendingInvites = pendingInvites;
      _activeCodes = activeCodes;
      _memberNames = names;
      _memberEmails = emails;
      _loading = false;
    });
  }

  Future<void> _createAccessCode() async {
    if (!_canManage) {
      _permission.ensure(context, AppPermission.manageUsers);
      return;
    }

    setState(() => _submitting = true);
    final result = await ProjectMembersService.instance.createTemporaryAccessCode(
      role: _role,
      expiresAt: _expiresAt,
      maxUses: _maxUses,
    );
    if (!mounted) return;

    setState(() => _submitting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );

    if (result.code != null) {
      await Clipboard.setData(ClipboardData(text: result.code!.code));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Código ${result.code!.code} copiado.')),
      );
    }
    await _reload();
  }

  Future<void> _pickExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: _expiresAt,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _expiresAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        23,
        59,
        59,
      );
    });
  }

  String _roleLabel(String role) {
    switch (role) {
      case UserProjectMembership.roleAdmin:
        return 'Admin';
      case UserProjectMembership.roleManager:
        return 'Gestor';
      case UserProjectMembership.roleInspector:
        return 'Inspetor';
      default:
        return 'Leitor';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final projectName = ProjectContextService.instance.currentProjectNameSync;

    return Scaffold(
      appBar: AppBar(title: const Text('Membros da obra')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _reload,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Obra ativa: $projectName',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Gerar código temporário de acesso',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (!_canManage)
                              Text(
                                'Somente admin pode gerenciar usuários nesta obra.',
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              initialValue: _role,
                              onChanged: !_canManage || _submitting
                                  ? null
                                  : (value) {
                                      if (value == null) return;
                                      setState(() => _role = value);
                                    },
                              items: const [
                                DropdownMenuItem(
                                  value: UserProjectMembership.roleAdmin,
                                  child: Text('Admin'),
                                ),
                                DropdownMenuItem(
                                  value: UserProjectMembership.roleManager,
                                  child: Text('Gestor'),
                                ),
                                DropdownMenuItem(
                                  value: UserProjectMembership.roleInspector,
                                  child: Text('Inspetor'),
                                ),
                                DropdownMenuItem(
                                  value: UserProjectMembership.roleViewer,
                                  child: Text('Leitor'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Validade do código'),
                              subtitle: Text(
                                '${_expiresAt.day.toString().padLeft(2, '0')}/${_expiresAt.month.toString().padLeft(2, '0')}/${_expiresAt.year}',
                              ),
                              trailing: OutlinedButton(
                                onPressed: !_canManage || _submitting
                                    ? null
                                    : _pickExpiryDate,
                                child: const Text('Alterar'),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              initialValue: '1',
                              enabled: _canManage && !_submitting,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Quantidade de usos',
                                helperText: 'Pode iniciar com 1 uso por código',
                              ),
                              onChanged: (value) {
                                final parsed = int.tryParse(value);
                                if (parsed == null || parsed <= 0) return;
                                _maxUses = parsed;
                              },
                            ),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton.icon(
                                onPressed: _submitting ? null : _createAccessCode,
                                icon: _submitting
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.vpn_key_outlined),
                                label: const Text('Gerar código'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Códigos ativos',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_activeCodes.isEmpty)
                      Text(
                        'Sem códigos ativos no momento.',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      )
                    else
                      ..._activeCodes.map(
                        (code) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.qr_code_2_outlined),
                            title: Text(code.code),
                            subtitle: Text(
                              'Papel: ${_roleLabel(code.role)} • Usos: ${code.usedCount}/${code.maxUses} • Expira: ${code.expiresAt == null ? 'Sem expiração' : '${code.expiresAt!.day.toString().padLeft(2, '0')}/${code.expiresAt!.month.toString().padLeft(2, '0')}/${code.expiresAt!.year}'}',
                            ),
                            trailing: IconButton(
                              tooltip: 'Copiar código',
                              icon: const Icon(Icons.copy_outlined),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: code.code));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Código ${code.code} copiado.')),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      'Membros vinculados',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_memberships.isEmpty)
                      Text(
                        'Nenhum membro encontrado para esta obra.',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      )
                    else
                      ..._memberships.map((membership) {
                        final name = _memberNames[membership.userId];
                        final email = _memberEmails[membership.userId];
                        final label = name == null || name.trim().isEmpty
                            ? 'UID ${membership.userId.length > 8 ? membership.userId.substring(0, 8) : membership.userId}'
                            : name;
                        final subtitleParts = <String>[
                          if (email != null && email.trim().isNotEmpty) email.trim(),
                          'Papel: ${_roleLabel(membership.role)}',
                          membership.isActive ? 'Ativo' : 'Inativo',
                        ];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.person_outline),
                            title: Text(label),
                            subtitle: Text(subtitleParts.join(' • ')),
                            trailing: membership.isActive
                                ? const Icon(Icons.check_circle_outline, color: Colors.green)
                                : const Icon(Icons.block_outlined, color: Colors.orange),
                          ),
                        );
                      }),
                    const SizedBox(height: 12),
                    Text(
                      'Convites por e-mail (legado)',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_pendingInvites.isEmpty)
                      Text(
                        'Sem convites pendentes.',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      )
                    else
                      ..._pendingInvites.map(
                        (invite) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.mail_outline),
                            title: Text(invite.email),
                            subtitle: Text(
                              'Papel: ${_roleLabel(invite.role)} • ${invite.pendingSync ? 'Pendente sync' : 'Sincronizado'}',
                            ),
                            trailing: Icon(
                              invite.pendingSync ? Icons.cloud_off_outlined : Icons.schedule,
                              color: invite.pendingSync ? Colors.orange : scheme.primary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

