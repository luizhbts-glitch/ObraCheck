import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../models/company_record.dart';
import '../services/permission_service.dart';
import '../services/project_context_service.dart';
import '../services/sync_orchestrator.dart';
import '../utils/project_scope.dart';

Future<CompanyRecord?> showCompanyFormDialog({
  required BuildContext context,
  required Box<CompanyRecord> box,
  CompanyRecord? initial,
}) async {
  if (!PermissionService.instance.ensure(context, AppPermission.editRegistry)) {
    return null;
  }

  final nomeController = TextEditingController(text: initial?.nome ?? '');
  final espController = TextEditingController(text: initial?.especialidade ?? '');
  final cnpjController = TextEditingController(text: initial?.cnpj ?? '');
  final phoneController = TextEditingController(text: initial?.phone ?? '');
  final activeProjectId = ProjectContextService.instance.currentProjectIdSync;

  final saved = await showDialog<CompanyRecord?>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(initial == null ? 'Adicionar empreiteiro' : 'Editar empreiteiro'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomeController,
                decoration: const InputDecoration(labelText: 'Nome', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: espController,
                decoration: const InputDecoration(labelText: 'Especialidade', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: cnpjController,
                decoration: const InputDecoration(labelText: 'CNPJ (opcional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Telefone / WhatsApp (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              final nome = nomeController.text.trim();
              final especialidade = espController.text.trim();
              final cnpj = cnpjController.text.trim();
              final phone = phoneController.text.trim();
              if (nome.isEmpty || especialidade.isEmpty) return;

              final duplicated = box.values.any((c) {
                if (initial != null && c.id == initial.id) return false;
                if (!matchesActiveProject(
                  activeProjectId: activeProjectId,
                  recordProjectId: c.projectId,
                )) {
                  return false;
                }
                return c.nome.trim().toLowerCase() == nome.toLowerCase();
              });
              if (duplicated) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Já existe empreiteiro com este nome.')),
                );
                return;
              }

              final now = DateTime.now();
              final id = initial?.id ?? 'company:$activeProjectId:${_companyIdFromName(nome)}';
              final currentProjectId = ProjectContextService.instance.currentProjectIdSync;
              Navigator.pop(
                dialogContext,
                CompanyRecord(
                  id: id,
                  nome: nome,
                  especialidade: especialidade,
                  cnpj: cnpj.isEmpty ? null : cnpj,
                  createdAt: initial?.createdAt ?? now,
                  updatedAt: now,
                  deleted: false,
                  pendingSync: true,
                  deletedAt: null,
                  projectId: currentProjectId,
                  phone: phone.isEmpty ? null : phone,
                ),
              );
            },
            child: const Text('Salvar'),
          ),
        ],
      );
    },
  );

  nomeController.dispose();
  espController.dispose();
  cnpjController.dispose();
  phoneController.dispose();
  if (saved == null) return null;
  final currentProjectId = await ProjectContextService.instance.getCurrentProjectId();
  final scoped = saved.copyWith(projectId: currentProjectId);
  await box.put(scoped.id, scoped);
  await SyncOrchestrator.instance.refreshPendingSnapshot();
  return scoped;
}

String _companyIdFromName(String nome) {
  final base = nome
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll(RegExp(r'[^a-z0-9_]'), '');
  return base.isEmpty ? DateTime.now().microsecondsSinceEpoch.toString() : base;
}

