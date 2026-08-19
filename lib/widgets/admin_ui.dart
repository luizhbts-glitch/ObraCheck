import 'package:flutter/material.dart';

import '../models/user_project_membership.dart';
import '../theme/app_colors.dart';

/// Peças visuais compartilhadas pelas telas de administração (construtoras
/// e membros da obra), pra dar uma cara consistente e mais profissional
/// do que ListTile/ExpansionTile cru.

class RoleVisual {
  const RoleVisual(this.label, this.color, this.icon);

  final String label;
  final Color color;
  final IconData icon;
}

RoleVisual projectRoleVisual(BuildContext context, String role) {
  final c = context.appColors;
  switch (role) {
    case UserProjectMembership.roleAdmin:
      return RoleVisual('Admin', c.selected, Icons.shield_outlined);
    case UserProjectMembership.roleManager:
      return RoleVisual('Gestor', c.success, Icons.badge_outlined);
    case UserProjectMembership.roleInspector:
      return RoleVisual(
        'Inspetor',
        c.warning,
        Icons.fact_check_outlined,
      );
    default:
      return RoleVisual(
        'Leitor',
        c.textSecondary,
        Icons.visibility_outlined,
      );
  }
}

/// Círculo com iniciais extraídas de um nome ou email.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    this.radius = 20,
  });

  final String label;
  final Color background;
  final Color foreground;
  final double radius;

  String get _initials {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return '?';
    final namePart = trimmed.contains('@') ? trimmed.split('@').first : trimmed;
    final parts = namePart
        .split(RegExp(r'[\s._-]+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return trimmed[0].toUpperCase();
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: background,
      foregroundColor: foreground,
      child: Text(
        _initials,
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: radius * 0.62),
      ),
    );
  }
}

/// Selo pequeno colorido (papel, status ativo/inativo, etc).
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Cabeçalho de seção: ícone em círculo + título + contador/ação opcional.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
    this.color,
  });

  final IconData icon;
  final String title;
  final Widget? trailing;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final tint = color ?? appColors.selected;
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: tint),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: appColors.textPrimary,
            ),
          ),
        ),
        // ignore: use_null_aware_elements — a sintaxe `?trailing` quebra o hive_generator (build_runner)
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Estado vazio padronizado: ícone grande em círculo + texto.
class EmptyStateHint extends StatelessWidget {
  const EmptyStateHint({
    super.key,
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: appColors.surfaceAlt,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: appColors.textSecondary, size: 24),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: appColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
