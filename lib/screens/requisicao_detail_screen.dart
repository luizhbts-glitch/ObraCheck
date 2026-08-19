import 'package:flutter/material.dart';

import '../models/cotacao_record.dart';
import '../models/requisicao_compra_record.dart';
import '../services/compras_service.dart';
import '../theme/app_colors.dart';
import '../widgets/admin_ui.dart';
import 'cotacao_form_screen.dart';

T? _firstWhereOrNull<T>(Iterable<T> items, bool Function(T) test) {
  for (final item in items) {
    if (test(item)) return item;
  }
  return null;
}

/// Detalhe de uma requisição — cria uma nova (quando `requisicaoExistente`
/// é nulo) ou mostra itens + cotações + ações de uma já existente.
class RequisicaoDetailScreen extends StatefulWidget {
  const RequisicaoDetailScreen({
    super.key,
    required this.orgId,
    required this.projectId,
    this.solicitanteEmployeeId,
    this.requisicaoExistente,
  });

  final String orgId;
  final String projectId;
  final String? solicitanteEmployeeId;
  final RequisicaoCompraRecord? requisicaoExistente;

  @override
  State<RequisicaoDetailScreen> createState() => _RequisicaoDetailScreenState();
}

class _RequisicaoDetailScreenState extends State<RequisicaoDetailScreen> {
  final ComprasService _service = ComprasService.instance;

  String? _centroCustoId;
  String _urgencia = 'normal';
  final _observacaoController = TextEditingController();
  final List<ItemRequisicao> _itensNovaRequisicao = [];

  final _descricaoController = TextEditingController();
  final _quantidadeController = TextEditingController();
  final _unidadeController = TextEditingController();
  String? _materialSelecionadoId;

  bool get _isNova => widget.requisicaoExistente == null;

  @override
  void dispose() {
    _observacaoController.dispose();
    _descricaoController.dispose();
    _quantidadeController.dispose();
    _unidadeController.dispose();
    super.dispose();
  }

  void _adicionarItem() {
    if (_descricaoController.text.trim().isEmpty ||
        _quantidadeController.text.trim().isEmpty) {
      return;
    }
    setState(() {
      _itensNovaRequisicao.add(
        ItemRequisicao(
          materialCatalogoId: _materialSelecionadoId,
          descricao: _descricaoController.text.trim(),
          quantidade: _quantidadeController.text.trim(),
          unidade: _unidadeController.text.trim(),
        ),
      );
      _descricaoController.clear();
      _quantidadeController.clear();
      _unidadeController.clear();
      _materialSelecionadoId = null;
    });
  }

  Future<void> _salvarRequisicao() async {
    if (_itensNovaRequisicao.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adicione pelo menos um item.')),
      );
      return;
    }
    await _service.criarRequisicao(
      projectId: widget.projectId,
      centroCustoId: _centroCustoId,
      solicitanteEmployeeId: widget.solicitanteEmployeeId!,
      itens: _itensNovaRequisicao,
      urgencia: _urgencia,
      observacao: _observacaoController.text.trim().isEmpty
          ? null
          : _observacaoController.text.trim(),
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _rejeitar() async {
    final requisicao = widget.requisicaoExistente;
    if (requisicao == null) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rejeitar requisição'),
        content: Text('Marcar ${requisicao.codigo} como não aprovada?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Rejeitar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    await _service.rejeitarRequisicao(requisicao.id);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _novaCotacao() async {
    final requisicao = widget.requisicaoExistente;
    if (requisicao == null) return;
    final criada = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CotacaoFormScreen(orgId: widget.orgId, requisicao: requisicao),
      ),
    );
    if (criada == true && mounted) setState(() {});
  }

  Future<void> _aprovarCotacao(CotacaoRecord cotacao) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aprovar cotação'),
        content: Text(
          'Confirma ${cotacao.codigo} como vencedora? Isso gera o Pedido de Compra.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Aprovar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    final pedido = await _service.aprovarCotacao(cotacao.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Pedido ${pedido.codigo} criado.')),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;

    if (_isNova) {
      final centrosCusto = _service.centrosCusto(widget.projectId);
      final materiais = _service.materiaisCatalogo(widget.orgId);

      return Scaffold(
        appBar: AppBar(title: const Text('Nova requisição')),
        body: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            DropdownButtonFormField<String?>(
              initialValue: _centroCustoId,
              decoration: const InputDecoration(labelText: 'Centro de custo'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Sem centro de custo')),
                ...centrosCusto.map(
                  (c) => DropdownMenuItem(value: c.id, child: Text(c.codigoNome)),
                ),
              ],
              onChanged: (value) => setState(() => _centroCustoId = value),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _urgencia,
              decoration: const InputDecoration(labelText: 'Urgência'),
              items: const [
                DropdownMenuItem(value: 'normal', child: Text('Normal')),
                DropdownMenuItem(value: 'urgente', child: Text('Urgente')),
              ],
              onChanged: (value) => setState(() => _urgencia = value ?? 'normal'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _observacaoController,
              decoration: const InputDecoration(labelText: 'Observação (opcional)'),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      icon: Icons.add_shopping_cart_outlined,
                      title: 'Itens',
                      color: appColors.selected,
                      trailing: StatusBadge(
                        label: '${_itensNovaRequisicao.length}',
                        color: appColors.selected,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (materiais.isNotEmpty)
                      DropdownButtonFormField<String?>(
                        initialValue: _materialSelecionadoId,
                        decoration: const InputDecoration(
                          labelText: 'Produto do catálogo (opcional)',
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Digitar manualmente')),
                          ...materiais.map(
                            (m) => DropdownMenuItem(value: m.id, child: Text(m.produto)),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _materialSelecionadoId = value;
                            final material = value == null
                                ? null
                                : materiais.firstWhere((m) => m.id == value);
                            if (material != null) {
                              _descricaoController.text = material.produto;
                              _unidadeController.text = material.unidadeMedida;
                            }
                          });
                        },
                      ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descricaoController,
                      decoration: const InputDecoration(labelText: 'Descrição'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _quantidadeController,
                            decoration: const InputDecoration(labelText: 'Quantidade'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _unidadeController,
                            decoration: const InputDecoration(labelText: 'Unidade'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: _adicionarItem,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Adicionar item'),
                      ),
                    ),
                    if (_itensNovaRequisicao.isNotEmpty) ...[
                      const Divider(height: 20),
                      ..._itensNovaRequisicao.map(
                        (item) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(item.descricao),
                          subtitle: Text('${item.quantidade} ${item.unidade}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => setState(
                              () => _itensNovaRequisicao.remove(item),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _salvarRequisicao,
                icon: const Icon(Icons.check),
                label: const Text('Criar requisição'),
              ),
            ),
          ],
        ),
      );
    }

    final requisicao = widget.requisicaoExistente!;
    final cotacoes = _service.cotacoesDaRequisicao(requisicao.id);
    final centroCusto = requisicao.centroCustoId == null
        ? null
        : _firstWhereOrNull(
            _service.centrosCusto(widget.projectId, onlyActive: false),
            (c) => c.id == requisicao.centroCustoId,
          );
    final podeRejeitar = requisicao.status == StatusRequisicao.aberta ||
        requisicao.status == StatusRequisicao.emCotacao;

    return Scaffold(
      appBar: AppBar(title: Text(requisicao.codigo)),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (centroCusto != null)
                    Text(
                      centroCusto.codigoNome,
                      style: TextStyle(color: appColors.textSecondary, fontSize: 12),
                    ),
                  if (requisicao.observacao?.isNotEmpty == true) ...[
                    const SizedBox(height: 6),
                    Text(requisicao.observacao!),
                  ],
                  const SizedBox(height: 10),
                  ...requisicao.itens.map(
                    (item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Icon(Icons.circle, size: 6, color: appColors.textSecondary),
                          const SizedBox(width: 8),
                          Expanded(child: Text(item.descricao)),
                          Text(
                            '${item.quantidade} ${item.unidade}',
                            style: TextStyle(color: appColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(
                    icon: Icons.request_quote_outlined,
                    title: 'Cotações',
                    color: appColors.selected,
                    trailing: StatusBadge(
                      label: '${cotacoes.length}',
                      color: appColors.selected,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (cotacoes.isEmpty)
                    EmptyStateHint(
                      icon: Icons.request_quote_outlined,
                      message: 'Nenhuma cotação lançada ainda.',
                    )
                  else
                    ...cotacoes.map((cotacao) {
                      final fornecedor = _firstWhereOrNull(
                        _service.fornecedores(widget.orgId, onlyActive: false),
                        (f) => f.id == cotacao.fornecedorId,
                      );
                      return Card(
                        color: cotacao.vencedora
                            ? appColors.success.withValues(alpha: 0.08)
                            : null,
                        child: ListTile(
                          title: Text(fornecedor?.nome ?? 'Fornecedor'),
                          subtitle: Text(
                            'R\$ ${cotacao.valorTotal.toStringAsFixed(2)}'
                            '${cotacao.prazoEntrega != null ? ' · ${cotacao.prazoEntrega}' : ''}',
                          ),
                          trailing: cotacao.vencedora
                              ? StatusBadge(
                                  label: 'Vencedora',
                                  color: appColors.success,
                                  icon: Icons.check_circle_outline,
                                )
                              : requisicao.status == StatusRequisicao.virouPedido
                                  ? null
                                  : TextButton(
                                      onPressed: () => _aprovarCotacao(cotacao),
                                      child: const Text('Aprovar'),
                                    ),
                        ),
                      );
                    }),
                  if (requisicao.status != StatusRequisicao.virouPedido &&
                      requisicao.status != StatusRequisicao.rejeitada) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: _novaCotacao,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Nova cotação'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (podeRejeitar) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _rejeitar,
                icon: Icon(Icons.block_outlined, color: appColors.danger),
                label: Text('Rejeitar requisição', style: TextStyle(color: appColors.danger)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
