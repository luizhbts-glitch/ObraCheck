import 'package:flutter/material.dart';

import '../models/pedido_compra_record.dart';
import '../services/compras_service.dart';
import '../services/employee_service.dart';
import '../services/project_context_service.dart';
import '../theme/app_colors.dart';
import '../widgets/admin_ui.dart';

/// Compras > Ordem de compra. `saldoAtual` permite entrega parcial —
/// confirmado contra o sistema de referência (L7) em 2026-07-18.
class PedidosCompraScreen extends StatefulWidget {
  const PedidosCompraScreen({super.key, required this.orgId});

  final String orgId;

  @override
  State<PedidosCompraScreen> createState() => _PedidosCompraScreenState();
}

class _PedidosCompraScreenState extends State<PedidosCompraScreen> {
  final ComprasService _service = ComprasService.instance;
  String _busca = '';

  static const _statusLabel = {
    StatusPedidoCompra.pendenteAprovacao: 'Pendente aprovação',
    StatusPedidoCompra.aprovado: 'Aprovado',
    StatusPedidoCompra.enviado: 'Enviado',
    StatusPedidoCompra.recebidoParcial: 'Entrega parcial',
    StatusPedidoCompra.recebidoTotal: 'Finalizado',
    StatusPedidoCompra.cancelado: 'Cancelado',
  };

  Color _corStatus(AppColors c, String status) {
    switch (status) {
      case StatusPedidoCompra.recebidoTotal:
        return c.success;
      case StatusPedidoCompra.recebidoParcial:
        return c.statusPending;
      case StatusPedidoCompra.cancelado:
        return c.textSecondary;
      case StatusPedidoCompra.pendenteAprovacao:
        return c.warning;
      default:
        return c.selected;
    }
  }

  Future<void> _aprovar(PedidoCompraRecord pedido) async {
    final funcionario = EmployeeService.instance.funcionarioAtualDaObraAtiva();
    if (funcionario == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sua conta não está vinculada a um funcionário cadastrado.'),
        ),
      );
      return;
    }
    await _service.aprovarPedido(pedidoId: pedido.id, aprovadoPorEmployeeId: funcionario.id);
    if (mounted) setState(() {});
  }

  Future<void> _registrarRecebimento(PedidoCompraRecord pedido) async {
    final controller = TextEditingController(text: pedido.saldoAtual.toStringAsFixed(2));
    final valor = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Recebimento — ${pedido.codigo}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Saldo atual: R\$ ${pedido.saldoAtual.toStringAsFixed(2)}'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Valor recebido agora (R\$)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text.trim().replaceAll(',', '.'));
              Navigator.of(context).pop(parsed);
            },
            child: const Text('Registrar'),
          ),
        ],
      ),
    );
    if (valor == null || valor <= 0) return;
    await _service.registrarRecebimento(pedidoId: pedido.id, valorRecebido: valor);
    if (mounted) setState(() {});
  }

  Future<void> _cancelar(PedidoCompraRecord pedido) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar pedido'),
        content: Text('Cancelar ${pedido.codigo}? A requisição não é reaberta automaticamente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancelar pedido'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    await _service.cancelarPedido(pedido.id);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final projectId = ProjectContextService.instance.currentProjectIdSync;
    final todos = _service.pedidos(projectId);
    final fornecedores = {
      for (final f in _service.fornecedores(widget.orgId, onlyActive: false)) f.id: f.nome,
    };
    final termo = _busca.trim().toLowerCase();
    final filtrados = termo.isEmpty
        ? todos
        : todos
            .where((p) =>
                p.codigo.toLowerCase().contains(termo) ||
                (fornecedores[p.fornecedorId] ?? '').toLowerCase().contains(termo))
            .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Ordem de compra')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar por código ou fornecedor',
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
                        icon: Icons.receipt_long_outlined,
                        message: todos.isEmpty
                            ? 'Nenhum pedido de compra ainda.\nAprove uma cotação pra gerar o primeiro.'
                            : 'Nenhum pedido encontrado pra essa busca.',
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                    itemCount: filtrados.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final pedido = filtrados[index];
                      final cor = _corStatus(appColors, pedido.status);
                      final fornecedorNome = fornecedores[pedido.fornecedorId] ?? 'Fornecedor';
                      final entregaParcial = pedido.saldoAtual > 0 &&
                          pedido.saldoAtual < pedido.valorTotal;

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
                                      pedido.codigo,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontFamily: 'monospace',
                                        color: appColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  StatusBadge(
                                    label: _statusLabel[pedido.status] ?? pedido.status,
                                    color: cor,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(fornecedorNome, style: TextStyle(color: appColors.textSecondary)),
                              const SizedBox(height: 6),
                              Text(
                                'Total: R\$ ${pedido.valorTotal.toStringAsFixed(2)}'
                                '${entregaParcial ? ' · Saldo: R\$ ${pedido.saldoAtual.toStringAsFixed(2)}' : ''}',
                                style: TextStyle(fontWeight: FontWeight.w600, color: appColors.textPrimary),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: [
                                  if (pedido.status == StatusPedidoCompra.pendenteAprovacao)
                                    FilledButton.tonalIcon(
                                      onPressed: () => _aprovar(pedido),
                                      icon: const Icon(Icons.check, size: 16),
                                      label: const Text('Aprovar'),
                                    ),
                                  if (pedido.status == StatusPedidoCompra.aprovado ||
                                      pedido.status == StatusPedidoCompra.enviado ||
                                      pedido.status == StatusPedidoCompra.recebidoParcial)
                                    OutlinedButton.icon(
                                      onPressed: () => _registrarRecebimento(pedido),
                                      icon: const Icon(Icons.local_shipping_outlined, size: 16),
                                      label: const Text('Registrar recebimento'),
                                    ),
                                  if (pedido.status != StatusPedidoCompra.cancelado &&
                                      pedido.status != StatusPedidoCompra.recebidoTotal)
                                    TextButton.icon(
                                      onPressed: () => _cancelar(pedido),
                                      icon: Icon(Icons.close, size: 16, color: appColors.danger),
                                      label: Text('Cancelar', style: TextStyle(color: appColors.danger)),
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
