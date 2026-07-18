import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/project_invite_record.dart';
import '../models/project_access_code_record.dart';
import '../models/user_project_membership.dart';
import '../services/permission_service.dart';
import '../services/project_context_service.dart';
import '../services/project_members_service.dart';
import '../theme/app_colors.dart';
import '../widgets/admin_ui.dart';

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

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final projectName = ProjectContextService.instance.currentProjectNameSync;

    return Scaffold(
      appBar: AppBar(title: const Text('Membros da obra')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _reload,
                child: ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: appColors.selected.withValues(alpha: 0.14),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.apartment_outlined,
                                color: appColors.selected,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Obra ativa',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: appColors.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    projectName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15.5,
                                      color: appColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Gerar código de acesso ────────────────────────────
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SectionHeader(
                              icon: Icons.vpn_key_outlined,
                              title: 'Gerar código de acesso',
                              color: appColors.selected,
                            ),
                            if (!_canManage) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Somente admin pode gerenciar usuários nesta obra.',
                                style: TextStyle(
                                  color: appColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: _role,
                              onChanged: !_canManage || _submitting
                                  ? null
                                  : (value) {
                                      if (value == null) return;
                                      setState(() => _role = value);
                                    },
                              decoration: const InputDecoration(
                                labelText: 'Papel concedido',
                              ),
                              items: [
                                UserProjectMembership.roleAdmin,
                                UserProjectMembership.roleManager,
                                UserProjectMembership.roleInspector,
                                UserProjectMembership.roleViewer,
                              ]
                                  .map(
                                    (role) => DropdownMenuItem(
                                      value: role,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            projectRoleVisual(context, role).icon,
                                            size: 16,
                                            color: projectRoleVisual(context, role).color,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(projectRoleVisual(context, role).label),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: !_canManage || _submitting
                                        ? null
                                        : _pickExpiryDate,
                                    icon: const Icon(Icons.event_outlined, size: 16),
                                    label: Text('Expira ${_formatDate(_expiresAt)}'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              initialValue: '1',
                              enabled: _canManage && !_submitting,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Quantidade de usos',
                                helperText: 'Pode iniciar com 1 uso por código',
                                prefixIcon: Icon(Icons.repeat_outlined),
                              ),
                              onChanged: (value) {
                                final parsed = int.tryParse(value);
                                if (parsed == null || parsed <= 0) return;
                                _maxUses = parsed;
                              },
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _submitting ? null : _createAccessCode,
                                icon: _submitting
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.add_link),
                                label: const Text('Gerar código'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Códigos ativos ────────────────────────────────────
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SectionHeader(
                              icon: Icons.qr_code_2_outlined,
                              title: 'Códigos ativos',
                              color: appColors.warning,
                              trailing: StatusBadge(
                                label: '${_activeCodes.length}',
                                color: appColors.warning,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (_activeCodes.isEmpty)
                              EmptyStateHint(
                                icon: Icons.qr_code_2_outlined,
                                message: 'Sem códigos ativos no momento.',
                              )
                            else
                              ..._activeCodes.map((code) {
                                final role = projectRoleVisual(context, code.role);
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 5),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: appColors.surfaceAlt,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: appColors.border),
                                        ),
                                        child: Text(
                                          code.code,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.4,
                                            fontFamily: 'monospace',
                                            color: appColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            StatusBadge(
                                              label: role.label,
                                              color: role.color,
                                              icon: role.icon,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Usos: ${code.usedCount}/${code.maxUses} • '
                                              '${code.expiresAt == null ? 'Sem expiração' : 'Expira ${_formatDate(code.expiresAt!)}'}',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                color: appColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Copiar código',
                                        icon: const Icon(Icons.copy_outlined, size: 19),
                                        onPressed: () {
                                          Clipboard.setData(ClipboardData(text: code.code));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Código ${code.code} copiado.')),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Membros vinculados ────────────────────────────────
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SectionHeader(
                              icon: Icons.groups_outlined,
                              title: 'Membros vinculados',
                              color: appColors.success,
                              trailing: StatusBadge(
                                label: '${_memberships.length}',
                                color: appColors.success,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (_memberships.isEmpty)
                              EmptyStateHint(
                                icon: Icons.person_search_outlined,
                                message: 'Nenhum membro encontrado para esta obra.',
                              )
                            else
                              ..._memberships.map((membership) {
                                final name = _memberNames[membership.userId];
                                final email = _memberEmails[membership.userId];
                                final label = name == null || name.trim().isEmpty
                                    ? (email ?? membership.userId)
                                    : name;
                                final role = projectRoleVisual(context, membership.role);

                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      InitialsAvatar(
                                        label: label,
                                        background: role.color.withValues(alpha: 0.14),
                                        foreground: role.color,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              label,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: appColors.textPrimary,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (email != null &&
                                                email.trim().isNotEmpty &&
                                                email != label)
                                              Text(
                                                email,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: appColors.textSecondary,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            const SizedBox(height: 5),
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 4,
                                              children: [
                                                StatusBadge(
                                                  label: role.label,
                                                  color: role.color,
                                                  icon: role.icon,
                                                ),
                                                StatusBadge(
                                                  label: membership.isActive ? 'Ativo' : 'Inativo',
                                                  color: membership.isActive
                                                      ? appColors.success
                                                      : appColors.textSecondary,
                                                  icon: membership.isActive
                                                      ? Icons.check_circle_outline
                                                      : Icons.block_outlined,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Convites por e-mail (legado) ──────────────────────
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SectionHeader(
                              icon: Icons.mail_outline,
                              title: 'Convites por e-mail',
                              color: appColors.textSecondary,
                            ),
                            const SizedBox(height: 10),
                            if (_pendingInvites.isEmpty)
                              EmptyStateHint(
                                icon: Icons.mail_outline,
                                message: 'Sem convites pendentes.',
                              )
                            else
                              ..._pendingInvites.map((invite) {
                                final role = projectRoleVisual(context, invite.role);
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 5),
                                  child: Row(
                                    children: [
                                      InitialsAvatar(
                                        label: invite.email,
                                        background: appColors.surfaceAlt,
                                        foreground: appColors.textSecondary,
                                        radius: 16,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              invite.email,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: appColors.textPrimary,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 3),
                                            StatusBadge(
                                              label: role.label,
                                              color: role.color,
                                              icon: role.icon,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        invite.pendingSync
                                            ? Icons.cloud_off_outlined
                                            : Icons.schedule,
                                        size: 18,
                                        color: invite.pendingSync
                                            ? appColors.warning
                                            : appColors.selected,
                                      ),
                                    ],
                                  ),
                                );
                              }),
                          ],
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
