import 'package:flutter/material.dart';

import 'project_context_service.dart';

enum AppPermission {
  createProject,
  editRegistry,
  finalizeInspection,
  openNc,
  manageUsers,
}

class PermissionService {
  PermissionService._();

  static final PermissionService instance = PermissionService._();

  final ProjectContextService _context = ProjectContextService.instance;

  bool has(AppPermission permission) {
    switch (permission) {
      case AppPermission.createProject:
        return _context.canCreateProjectSync;
      case AppPermission.editRegistry:
        return _context.canEditRegistrySync;
      case AppPermission.finalizeInspection:
        return _context.canFinalizeInspectionSync;
      case AppPermission.openNc:
        return _context.canOpenNcSync;
      case AppPermission.manageUsers:
        return _context.canManageUsersSync;
    }
  }

  String deniedMessage(AppPermission permission) {
    switch (permission) {
      case AppPermission.createProject:
        return 'Sem permissão para criar obra.';
      case AppPermission.editRegistry:
        return 'Sem permissão para editar cadastros nesta obra.';
      case AppPermission.finalizeInspection:
        return 'Sem permissão para finalizar inspeção nesta obra.';
      case AppPermission.openNc:
        return 'Sem permissão para abrir NC nesta obra.';
      case AppPermission.manageUsers:
        return 'Sem permissão para gerenciar usuários nesta obra.';
    }
  }

  bool ensure(
    BuildContext context,
    AppPermission permission, {
    String? message,
  }) {
    final allowed = has(permission);
    if (allowed) return true;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message ?? deniedMessage(permission))),
    );
    return false;
  }
}

