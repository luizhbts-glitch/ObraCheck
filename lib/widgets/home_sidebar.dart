import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Um item do menu lateral da Home — mesma ação que hoje vive em
/// "Ações rápidas".
class SidebarAction {
  const SidebarAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final Future<void> Function() onTap;
  final String? subtitle;
  final bool busy;
}

/// Menu lateral estilo VS Code/Notion: recolhido por padrão (só ícones),
/// expande ao passar o mouse por cima, recolhe ao tirar — com botão de
/// fixar que trava expandido e ignora hover. Especificado com o usuário
/// em 2026-08-22.
class HomeSidebar extends StatefulWidget {
  const HomeSidebar({
    super.key,
    required this.items,
    required this.pinned,
    required this.onTogglePin,
  });

  final List<SidebarAction> items;
  final bool pinned;
  final ValueChanged<bool> onTogglePin;

  static const double collapsedWidth = 64;
  static const double expandedWidth = 232;

  @override
  State<HomeSidebar> createState() => _HomeSidebarState();
}

class _HomeSidebarState extends State<HomeSidebar> {
  bool _hovering = false;

  bool get _expanded => widget.pinned || _hovering;

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        width: _expanded ? HomeSidebar.expandedWidth : HomeSidebar.collapsedWidth,
        decoration: BoxDecoration(
          color: appColors.surfaceAlt,
          border: Border(right: BorderSide(color: appColors.border)),
        ),
        child: ClipRect(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Align(
                  alignment: _expanded ? Alignment.centerRight : Alignment.center,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: IconButton(
                      tooltip: widget.pinned ? 'Desafixar menu' : 'Fixar menu expandido',
                      onPressed: () => widget.onTogglePin(!widget.pinned),
                      icon: Icon(widget.pinned ? Icons.push_pin : Icons.push_pin_outlined),
                    ),
                  ),
                ),
                Divider(height: 1, color: appColors.border),
                const SizedBox(height: 4),
                for (final item in widget.items)
                  _SidebarTile(expanded: _expanded, action: item),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({required this.expanded, required this.action});

  final bool expanded;
  final SidebarAction action;

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final tile = InkWell(
      onTap: action.busy ? null : () => action.onTap(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: action.busy
                  ? const Padding(
                      padding: EdgeInsets.all(3),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(action.icon, color: appColors.textPrimary),
            ),
            if (expanded) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      action.label,
                      style: TextStyle(color: appColors.textPrimary, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    if (action.subtitle != null)
                      Text(
                        action.subtitle!,
                        style: TextStyle(color: appColors.textSecondary, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (expanded) return tile;
    return Tooltip(message: action.label, child: tile);
  }
}
