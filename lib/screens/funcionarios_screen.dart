import 'package:flutter/material.dart';

import '../services/employee_service.dart';
import '../services/project_context_service.dart';
import '../theme/app_colors.dart';
import '../widgets/admin_ui.dart';
import 'cargos_screen.dart';

/// RH > Funcionários. Campos confirmados contra o sistema de referência
/// (L7) em 2026-07-18: ID, Obra (ou "Adm"), Cargo, Nome, Avaliador, Status.
class FuncionariosScreen extends StatefulWidget {
  const FuncionariosScreen({super.key, required this.orgId});

  final String orgId;

  @override
  State<FuncionariosScreen> createState() => _FuncionariosScreenState();
}

class _FuncionariosScreenState extends State<FuncionariosScreen> {
  final EmployeeService _service = EmployeeService.instance;
  String _busca = '';

  Future<void> _novoFuncionario() async {
    final cargos = _service.cargos(widget.orgId);
    if (cargos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cadastre pelo menos um cargo antes de adicionar funcionário.'),
        ),
      );
      return;
    }

    final nomeController = TextEditingController();
    final projetos = ProjectContextService.instance.allProjects();
    var cargoId = cargos.first.id;
    String? projectId; // null = Adm (escritório)
    String? avaliadorId;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          icon: const Icon(Icons.person_add_alt_outlined),
          title: const Text('Novo funcionário'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nomeController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: cargoId,
                  decoration: const InputDecoration(labelText: 'Cargo'),
                  items: cargos
                      .map((c) => DropdownMenuItem(value: c.id, child: Text(c.nome)))
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() => cargoId = value);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: projectId,
                  decoration: const InputDecoration(labelText: 'Obra'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Adm (escritório)')),
                    ...projetos.map(
                      (p) => DropdownMenuItem(value: p.id, child: Text(p.name)),
                    ),
                  ],
                  onChanged: (value) => setDialogState(() => projectId = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: avaliadorId,
                  decoration: const InputDecoration(labelText: 'Avaliador (opcional)'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Nenhum')),
                    ..._service.funcionarios(widget.orgId).map(
                          (e) => DropdownMenuItem(value: e.id, child: Text(e.nome)),
                        ),
                  ],
                  onChanged: (value) => setDialogState(() => avaliadorId = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Criar'),
            ),
          ],
        ),
      ),
    );

    if (result != true || nomeController.text.trim().isEmpty) return;
    await _service.criarFuncionario(
      orgId: widget.orgId,
      projectId: projectId ?? '',
      cargoId: cargoId,
      nome: nomeController.text,
      avaliadorEmployeeId: avaliadorId,
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final todos = _service.funcionarios(widget.orgId, onlyActive: false);
    final filtrados = _busca.trim().isEmpty
        ? todos
        : todos
            .where((e) => e.nome.toLowerCase().contains(_busca.toLowerCase()))
            .toList();
    final projetosById = {
      for (final p in ProjectContextService.instance.allProjects()) p.id: p.name,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Funcionários')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar por nome',
                isDense: true,
              ),
              onChanged: (value) => setState(() => _busca = value),
            ),
          ),
          Expanded(
            child: filtrados.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: EmptyStateHint(
                        icon: Icons.people_outline,
                        message: 'Nenhum funcionário encontrado.',
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
                    itemCount: filtrados.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final funcionario = filtrados[index];
                      final cargo = _service.cargoById(funcionario.cargoId);
                      final obraNome = funcionario.projectId.isEmpty
                          ? 'Adm'
                          : (projetosById[funcionario.projectId] ?? funcionario.projectId);
                      final avaliador = _service.porId(funcionario.avaliadorEmployeeId);

                      return Card(
                        child: ListTile(
                          leading: InitialsAvatar(
                            label: funcionario.nome,
                            background: appColors.selected.withValues(alpha: 0.14),
                            foreground: appColors.selected,
                          ),
                          title: Text(funcionario.nome),
                          subtitle: Text(
                            '${cargo?.nome ?? 'Sem cargo'} · $obraNome'
                            '${avaliador != null ? ' · resp.: ${avaliador.nome}' : ''}',
                          ),
                          trailing: Switch(
                            value: funcionario.isActive,
                            onChanged: (value) async {
                              await _service.definirAtivo(
                                employeeId: funcionario.id,
                                isActive: value,
                              );
                              if (mounted) setState(() {});
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'cargos',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CargosScreen(orgId: widget.orgId),
                ),
              );
            },
            icon: const Icon(Icons.badge_outlined),
            label: const Text('Cargo'),
          ),
          const SizedBox(width: 10),
          FloatingActionButton.extended(
            heroTag: 'novo',
            onPressed: _novoFuncionario,
            icon: const Icon(Icons.add),
            label: const Text('Novo'),
          ),
        ],
      ),
    );
  }
}
