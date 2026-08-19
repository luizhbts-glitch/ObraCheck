import 'package:flutter/material.dart';

import '../models/requisicao_compra_record.dart';
import '../services/compras_service.dart';
import '../services/employee_service.dart';
import '../services/project_context_service.dart';
import '../theme/app_colors.dart';
import '../utils/compras_status.dart';
import '../widgets/admin_ui.dart';
import 'requisicao_detail_screen.dart';

/// Compras > Requisições — quadro Kanban por status, confirmado contra a
/// ferramenta pessoal do usuário em 2026-07-18 (ver nota "Referência L7"
/// no Obsidian).
class RequisicoesScreen extends StatefulWidget {
  const RequisicoesScreen({super.key, required this.orgId});

  final String orgId;

  @override
  State<RequisicoesScreen> createState() => _RequisicoesScreenState();
}

class _RequisicoesScreenState extends State<RequisicoesScreen> {
  final ComprasService _service = ComprasService.instance;
  String _busca = '';

  static const Map<String, Color Function(AppColors)> _corPorStatus = {
    KanbanStatusCompra.aprovacao: _corAprovacao,
    KanbanStatusCompra.cotacao: _corCotacao,
    KanbanStatusCompra.ocEmitida: _corOcEmitida,
    KanbanStatusCompra.chegadaParcial: _corChegadaParcial,
    KanbanStatusCompra.finalizado: _corFinalizado,
  };

  static Color _corAprovacao(AppColors c) => c.warning;
  static Color _corCotacao(AppColors c) => c.selected;
  static Color _corOcEmitida(AppColors c) => c.primaryAction;
  static Color _corChegadaParcial(AppColors c) => c.statusPending;
  static Color _corFinalizado(AppColors c) => c.success;

  Future<void> _novaRequisicao() async {
    final projectId = ProjectContextService.instance.currentProjectIdSync;
    final solicitante = EmployeeService.instance.funcionarioAtualDaObraAtiva();
    if (solicitante == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sua conta ainda não está vinculada a um funcionário cadastrado (RH > Funcionários).',
          ),
        ),
      );
      return;
    }

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RequisicaoDetailScreen(
          orgId: widget.orgId,
          projectId: projectId,
          solicitanteEmployeeId: solicitante.id,
        ),
      ),
    );
    if (result == true && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final projectId = ProjectContextService.instance.currentProjectIdSync;
    final todas = _service.requisicoes(projectId);
    final termo = _busca.trim().toLowerCase();
    final filtradas = termo.isEmpty
        ? todas
        : todas
            .where((r) =>
                r.codigo.toLowerCase().contains(termo) ||
                r.itens.any((i) => i.descricao.toLowerCase().contains(termo)))
            .toList();

    final porStatus = <String, List<RequisicaoCompraRecord>>{
      for (final status in KanbanStatusCompra.ordem) status: [],
    };
    for (final requisicao in filtradas) {
      final pedido = _service.pedidoDaRequisicao(requisicao.id);
      final status = calcularStatusKanbanCompra(requisicao: requisicao, pedido: pedido);
      if (status == KanbanStatusCompra.naoAprovada) continue; // fora do quadro, some da lista
      porStatus.putIfAbsent(status, () => []).add(requisicao);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Requisições')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _novaRequisicao,
        icon: const Icon(Icons.add),
        label: const Text('Nova requisição'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar por código ou item',
                isDense: true,
              ),
              onChanged: (value) => setState(() => _busca = value),
            ),
          ),
          Expanded(
            child: todas.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: EmptyStateHint(
                        icon: Icons.assignment_outlined,
                        message: 'Nenhuma requisição nesta obra ainda.',
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final status in KanbanStatusCompra.ordem)
                          _KanbanColuna(
                            titulo: status,
                            cor: _corPorStatus[status]!(appColors),
                            requisicoes: porStatus[status] ?? const [],
                            onTapCard: (requisicao) async {
                              final result = await Navigator.of(context).push<bool>(
                                MaterialPageRoute(
                                  builder: (_) => RequisicaoDetailScreen(
                                    orgId: widget.orgId,
                                    projectId: projectId,
                                    requisicaoExistente: requisicao,
                                  ),
                                ),
                              );
                              if (result == true && mounted) setState(() {});
                            },
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _KanbanColuna extends StatelessWidget {
  const _KanbanColuna({
    required this.titulo,
    required this.cor,
    required this.requisicoes,
    required this.onTapCard,
  });

  final String titulo;
  final Color cor;
  final List<RequisicaoCompraRecord> requisicoes;
  final void Function(RequisicaoCompraRecord) onTapCard;

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    return Container(
      width: 260,
      margin: const EdgeInsets.only(right: 10, bottom: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: appColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: appColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    titulo,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: appColors.textPrimary,
                    ),
                  ),
                ),
                StatusBadge(label: '${requisicoes.length}', color: cor),
              ],
            ),
          ),
          const SizedBox(height: 6),
          if (requisicoes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  '—',
                  style: TextStyle(color: appColors.textSecondary),
                ),
              ),
            )
          else
            ...requisicoes.map(
              (requisicao) => Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onTapCard(requisicao),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          requisicao.codigo,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: appColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          requisicao.itens.isEmpty
                              ? 'Sem itens'
                              : requisicao.itens.map((i) => i.descricao).join(', '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: appColors.textSecondary),
                        ),
                        if (requisicao.urgencia == 'urgente') ...[
                          const SizedBox(height: 6),
                          StatusBadge(
                            label: 'Urgente',
                            color: appColors.danger,
                            icon: Icons.priority_high,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
