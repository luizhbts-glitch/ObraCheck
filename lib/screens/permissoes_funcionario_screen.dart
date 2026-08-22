import 'package:flutter/material.dart';

import '../models/employee_record.dart';
import '../services/employee_service.dart';
import '../services/project_context_service.dart';
import '../theme/app_colors.dart';
import '../utils/erp_permission.dart';
import '../utils/permission_catalog.dart';

/// Controle de acesso por pessoa — edição direta de permissões granulares
/// (módulo > entidade > ação) do funcionário, sem passar por um "Perfil
/// de Acesso" nomeado (decisão de 2026-08-22: por pessoa é o mecanismo
/// principal, não perfil).
///
/// Acesso restrito a quem já tem acesso elevado (diretoria/admin global)
/// — só essas pessoas podem abrir esta tela, então dentro dela elas têm
/// poder de conceder/revogar qualquer permissão do catálogo sem
/// restrição adicional de "regra do teto" (`canGrant`/`isInReportingChain`
/// em `erp_permission.dart` ficam disponíveis pra quando uma versão
/// futura permitir que níveis intermediários editem permissão dos seus
/// subordinados especificamente).
class PermissoesFuncionarioScreen extends StatefulWidget {
  const PermissoesFuncionarioScreen({super.key, required this.employee});

  final EmployeeRecord employee;

  @override
  State<PermissoesFuncionarioScreen> createState() => _PermissoesFuncionarioScreenState();
}

class _PermissoesFuncionarioScreenState extends State<PermissoesFuncionarioScreen> {
  final EmployeeService _service = EmployeeService.instance;
  late EmployeeRecord _employee = widget.employee;

  bool get _podeEditar => ProjectContextService.instance.hasElevatedAccessSync;

  String get _concedidoPorEmployeeId {
    final atual = EmployeeService.instance.funcionarioAtual(_employee.orgId);
    return atual?.id ?? '';
  }

  Future<void> _toggle(String modulo, String entidade, String acao, bool liberado) async {
    await _service.definirPermissao(
      employeeId: _employee.id,
      modulo: modulo,
      entidade: entidade,
      acao: acao,
      liberado: liberado,
      concedidoPorEmployeeId: _concedidoPorEmployeeId,
    );
    final atualizado = _service.porId(_employee.id);
    if (atualizado != null && mounted) {
      setState(() => _employee = atualizado);
    }
  }

  Future<void> _limparTudo() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpar permissões'),
        content: Text(
          'Tem certeza que quer remover todos os ajustes de permissão de "${_employee.nome}"? '
          'Isso volta ao estado sem nenhuma permissão granular concedida.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Limpar')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _service.limparPermissoes(_employee.id);
    final atualizado = _service.porId(_employee.id);
    if (atualizado != null && mounted) {
      setState(() => _employee = atualizado);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;

    if (!_podeEditar) {
      return Scaffold(
        appBar: AppBar(title: const Text('Permissões')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Só quem tem acesso elevado (diretoria ou admin) pode ver ou editar permissões.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final grouped = groupPermissionCatalogByModulo();
    final modulos = grouped.keys.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Permissões — ${_employee.nome}'),
        actions: [
          TextButton(
            onPressed: _limparTudo,
            child: const Text('Limpar tudo', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: modulos.length,
        itemBuilder: (context, i) {
          final modulo = modulos[i];
          final entidades = grouped[modulo]!;
          return Card(
            child: ExpansionTile(
              title: Text(modulo, style: const TextStyle(fontWeight: FontWeight.w800)),
              children: entidades.map((entry) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.entidade, style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: entry.acoes.map((acao) {
                          final liberado = hasErpPermission(
                            employee: _employee,
                            perfil: null,
                            modulo: entry.modulo,
                            entidade: entry.entidade,
                            acao: acao,
                          );
                          return FilterChip(
                            label: Text(acaoLabel(acao)),
                            selected: liberado,
                            selectedColor: appColors.selected.withValues(alpha: 0.25),
                            onSelected: (value) => _toggle(entry.modulo, entry.entidade, acao, value),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}
