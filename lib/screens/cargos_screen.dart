import 'package:flutter/material.dart';

import '../services/employee_service.dart';
import '../theme/app_colors.dart';
import '../widgets/admin_ui.dart';

/// Catálogo de cargos da construtora — organograma (nível 1=Diretor a
/// 6=Estagiário, decidido em 2026-07-18).
class CargosScreen extends StatefulWidget {
  const CargosScreen({super.key, required this.orgId});

  final String orgId;

  @override
  State<CargosScreen> createState() => _CargosScreenState();
}

class _CargosScreenState extends State<CargosScreen> {
  final EmployeeService _service = EmployeeService.instance;

  static const _nomesNivel = {
    1: 'Diretor',
    2: 'TI',
    3: 'Coordenador de obras',
    4: 'Engenheiro/Compras/Financeiro',
    5: 'Auxiliar/Administrativo/Comercial',
    6: 'Estagiário',
  };

  Future<void> _novoCargo() async {
    final nomeController = TextEditingController();
    var nivel = 4;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          icon: const Icon(Icons.badge_outlined),
          title: const Text('Novo cargo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nomeController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nome do cargo',
                  hintText: 'Ex.: Engenheiro',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: nivel,
                decoration: const InputDecoration(labelText: 'Nível no organograma'),
                items: _nomesNivel.entries
                    .map(
                      (e) => DropdownMenuItem(
                        value: e.key,
                        child: Text('${e.key} — ${e.value}'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setDialogState(() => nivel = value);
                },
              ),
            ],
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
    await _service.criarCargo(
      orgId: widget.orgId,
      nome: nomeController.text,
      nivelHierarquico: nivel,
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final cargos = _service.cargos(widget.orgId);

    return Scaffold(
      appBar: AppBar(title: const Text('Cargos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _novoCargo,
        icon: const Icon(Icons.add),
        label: const Text('Novo cargo'),
      ),
      body: cargos.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: EmptyStateHint(
                  icon: Icons.badge_outlined,
                  message: 'Nenhum cargo cadastrado ainda.\nComece pelo organograma da sua construtora.',
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              itemCount: cargos.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final cargo = cargos[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: appColors.selected.withValues(alpha: 0.14),
                      foregroundColor: appColors.selected,
                      child: Text('${cargo.nivelHierarquico}'),
                    ),
                    title: Text(cargo.nome),
                    subtitle: Text(
                      _nomesNivel[cargo.nivelHierarquico] ?? 'Nível ${cargo.nivelHierarquico}',
                    ),
                  ),
                );
              },
            ),
    );
  }
}
