import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/company_record.dart';
import '../models/inspection_record.dart';
import '../models/service_record.dart';
import '../services/permission_service.dart';
import '../services/project_context_service.dart';
import '../services/sync_orchestrator.dart';
import '../utils/project_scope.dart';
import 'company_form_screen.dart';
import 'empreiteiro_profile_screen.dart';

class EmpreiteirosScreen extends StatelessWidget {
  const EmpreiteirosScreen({super.key});

  Future<void> _deleteCompany(
    BuildContext context,
    CompanyRecord company,
  ) async {
    final allowed = PermissionService.instance.ensure(
      context,
      AppPermission.editRegistry,
    );
    if (!allowed) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir empreiteiro'),
        content: Text('Deseja excluir ${company.nome}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final companiesBox = Hive.box<CompanyRecord>('companies');
    final tombstone = company.copyWith(
      deleted: true,
      pendingSync: true,
      deletedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await companiesBox.put(company.id, tombstone);
    await SyncOrchestrator.instance.refreshPendingSnapshot();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Empreiteiro excluído.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final companiesBox = Hive.box<CompanyRecord>('companies');
    final servicesBox = Hive.box<ServiceRecord>('services');
    final inspectionsBox = Hive.box<InspectionRecord>('inspections');
    final projectContext = ProjectContextService.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('Empreiteiros')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final allowed = PermissionService.instance.ensure(
            context,
            AppPermission.editRegistry,
          );
          if (!allowed) return;
          await showCompanyFormDialog(
            context: context,
            box: companiesBox,
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Adicionar empreiteiro'),
      ),
      body: ValueListenableBuilder<Box<InspectionRecord>>(
        valueListenable: inspectionsBox.listenable(),
        builder: (context, inspectionsValue, _) {
          return ValueListenableBuilder<Box<CompanyRecord>>(
            valueListenable: companiesBox.listenable(),
            builder: (context, value, _) {
              final currentProjectId = projectContext.currentProjectIdSync;
              final scopedCompanies = filterRecordsByProjectScope(
                value.values,
                currentProjectId: currentProjectId,
                projectId: (c) => c.projectId,
              ).toList();
              final scopedInspections = filterRecordsByProjectScope(
                inspectionsValue.values,
                currentProjectId: currentProjectId,
                projectId: (r) => r.projectId,
                obra: (r) => r.obra,
              ).toList();

              final list = scopedCompanies
                ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
              if (list.isEmpty) {
                return const Center(child: Text('Nenhum empreiteiro cadastrado.'));
              }
              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: list.length,
                separatorBuilder: (_, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final c = list[index];
                  final ncCount = scopedInspections.where((r) {
                    if (r.deleted) return false;
                    if ((r.ncCompanyId ?? '').trim() != c.id) return false;
                    return r.itens.any((item) => item.status == 'nok');
                  }).length;
                  return Card(
                    child: ListTile(
                      title: Text(c.nome),
                      subtitle: Text('${c.especialidade} • NC: $ncCount'),
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            tooltip: 'Excluir empreiteiro',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async => _deleteCompany(context, c),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EmpreiteiroProfileScreen(
                              company: c,
                              servicesBox: servicesBox,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

