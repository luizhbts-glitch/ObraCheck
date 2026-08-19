import 'package:flutter/material.dart';

import '../models/despesa_record.dart';
import '../services/despesas_service.dart';
import '../services/employee_service.dart';
import '../services/project_context_service.dart';
import '../theme/app_colors.dart';
import '../widgets/admin_ui.dart';

/// Despesas — lançamento avulso (não controlado), aprovação por nível do
/// organograma, e visão de vencimentos. Despesas controladas (vindas de
/// Ordem de compra ou Medição de empreiteiro) aparecem aqui também, mas
/// nascem automaticamente nos respectivos fluxos — não têm botão de
/// lançamento manual próprio ainda.
class DespesasScreen extends StatefulWidget {
  const DespesasScreen({super.key, required this.orgId});

  final String orgId;

  @override
  State<DespesasScreen> createState() => _DespesasScreenState();
}

class _DespesasScreenState extends State<DespesasScreen> {
  final DespesasService _service = DespesasService.instance;
  String _busca = '';

  static const _statusLabel = {
    StatusDespesa.lancada: 'Lançada',
    StatusDespesa.aguardandoAprovacao: 'Aguardando aprovação',
    StatusDespesa.aprovada: 'Aprovada',
    StatusDespesa.rejeitada: 'Rejeitada',
    StatusDespesa.paga: 'Paga',
  };

  Color _corStatus(AppColors c, String status) {
    switch (status) {
      case StatusDespesa.paga:
        return c.success;
      case StatusDespesa.aprovada:
        return c.selected;
      case StatusDespesa.rejeitada:
        return c.danger;
      default:
        return c.warning;
    }
  }

  Future<void> _lancarDespesa() async {
    final funcionario = EmployeeService.instance.funcionarioAtualDaObraAtiva();
    if (funcionario == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sua conta não está vinculada a um funcionário cadastrado.'),
        ),
      );
      return;
    }

    final projectId = ProjectContextService.instance.currentProjectIdSync;
    final descricaoController = TextEditingController();
    final valorController = TextEditingController();
    DateTime? vencimento;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          icon: const Icon(Icons.receipt_outlined),
          title: const Text('Lançar despesa'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: descricaoController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Descrição'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: valorController,
                  decoration: const InputDecoration(labelText: 'Valor (R\$)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    vencimento == null
                        ? 'Sem vencimento definido'
                        : 'Vencimento: ${vencimento!.day.toString().padLeft(2, '0')}/'
                            '${vencimento!.month.toString().padLeft(2, '0')}/${vencimento!.year}',
                  ),
                  trailing: TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        initialDate: DateTime.now(),
                      );
                      if (picked != null) setDialogState(() => vencimento = picked);
                    },
                    child: const Text('Escolher'),
                  ),
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
              child: const Text('Lançar'),
            ),
          ],
        ),
      ),
    );

    if (result != true || !mounted) return;
    final valor = double.tryParse(valorController.text.trim().replaceAll(',', '.'));
    if (descricaoController.text.trim().isEmpty || valor == null || valor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha descrição e valor corretamente.')),
      );
      return;
    }

    await _service.lancarDespesa(
      projectId: projectId,
      tipo: TipoDespesa.naoControlada,
      origem: OrigemDespesa.avulsa,
      descricao: descricaoController.text.trim(),
      valor: valor,
      vencimento: vencimento,
      lancadoPorEmployeeId: funcionario.id,
    );
    if (mounted) setState(() {});
  }

  Future<void> _aprovar(DespesaRecord despesa) async {
    final funcionario = EmployeeService.instance.funcionarioAtualDaObraAtiva();
    if (funcionario == null) return;
    if (!_service.podeAprovarDespesa(widget.orgId, funcionario.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Só quem está no nível de Engenheiro/Coordenador/TI/Diretor pode aprovar despesa.',
          ),
        ),
      );
      return;
    }
    await _service.aprovarDespesa(despesaId: despesa.id, aprovadoPorEmployeeId: funcionario.id);
    if (mounted) setState(() {});
  }

  Future<void> _rejeitar(DespesaRecord despesa) async {
    final funcionario = EmployeeService.instance.funcionarioAtualDaObraAtiva();
    if (funcionario == null) return;
    if (!_service.podeAprovarDespesa(widget.orgId, funcionario.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Só quem está no nível de Engenheiro/Coordenador/TI/Diretor pode rejeitar despesa.',
          ),
        ),
      );
      return;
    }
    await _service.rejeitarDespesa(despesa.id);
    if (mounted) setState(() {});
  }

  Future<void> _marcarPaga(DespesaRecord despesa) async {
    await _service.marcarComoPaga(despesa.id);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final projectId = ProjectContextService.instance.currentProjectIdSync;
    final todas = _service.despesas(projectId);
    final termo = _busca.trim().toLowerCase();
    final filtradas = termo.isEmpty
        ? todas
        : todas
            .where((d) =>
                d.codigo.toLowerCase().contains(termo) ||
                (d.descricao ?? '').toLowerCase().contains(termo))
            .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Despesas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _lancarDespesa,
        icon: const Icon(Icons.add),
        label: const Text('Lançar despesa'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar por código ou descrição',
                isDense: true,
              ),
              onChanged: (value) => setState(() => _busca = value),
            ),
          ),
          Expanded(
            child: filtradas.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: EmptyStateHint(
                        icon: Icons.receipt_long_outlined,
                        message: todas.isEmpty
                            ? 'Nenhuma despesa lançada ainda.'
                            : 'Nenhuma despesa encontrada pra essa busca.',
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                    itemCount: filtradas.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final despesa = filtradas[index];
                      final cor = _corStatus(appColors, despesa.status);
                      final vencimento = despesa.vencimento;

                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      despesa.codigo,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontFamily: 'monospace',
                                        color: appColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  StatusBadge(
                                    label: despesa.tipo == TipoDespesa.controlada
                                        ? 'Controlada'
                                        : 'Não controlada',
                                    color: despesa.tipo == TipoDespesa.controlada
                                        ? appColors.selected
                                        : appColors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  StatusBadge(
                                    label: _statusLabel[despesa.status] ?? despesa.status,
                                    color: cor,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(despesa.descricao ?? 'Sem descrição'),
                              const SizedBox(height: 6),
                              Text(
                                'R\$ ${despesa.valor.toStringAsFixed(2)}'
                                '${vencimento != null ? ' · Vence ${vencimento.day.toString().padLeft(2, '0')}/${vencimento.month.toString().padLeft(2, '0')}/${vencimento.year}' : ''}',
                                style: TextStyle(fontWeight: FontWeight.w600, color: appColors.textPrimary),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: [
                                  if (despesa.status == StatusDespesa.lancada) ...[
                                    FilledButton.tonalIcon(
                                      onPressed: () => _aprovar(despesa),
                                      icon: const Icon(Icons.check, size: 16),
                                      label: const Text('Aprovar'),
                                    ),
                                    TextButton.icon(
                                      onPressed: () => _rejeitar(despesa),
                                      icon: Icon(Icons.close, size: 16, color: appColors.danger),
                                      label: Text('Rejeitar', style: TextStyle(color: appColors.danger)),
                                    ),
                                  ],
                                  if (despesa.status == StatusDespesa.aprovada)
                                    OutlinedButton.icon(
                                      onPressed: () => _marcarPaga(despesa),
                                      icon: const Icon(Icons.paid_outlined, size: 16),
                                      label: const Text('Marcar como paga'),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
