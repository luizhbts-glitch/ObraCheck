import 'package:flutter/material.dart';

import '../models/cotacao_record.dart';
import '../models/requisicao_compra_record.dart';
import '../services/compras_service.dart';
import '../theme/app_colors.dart';

/// Nova cotação pra uma requisição: escolhe fornecedor, preenche valor
/// unitário de cada item (os itens vêm pré-carregados da requisição).
class CotacaoFormScreen extends StatefulWidget {
  const CotacaoFormScreen({
    super.key,
    required this.orgId,
    required this.requisicao,
  });

  final String orgId;
  final RequisicaoCompraRecord requisicao;

  @override
  State<CotacaoFormScreen> createState() => _CotacaoFormScreenState();
}

class _CotacaoFormScreenState extends State<CotacaoFormScreen> {
  final ComprasService _service = ComprasService.instance;

  String? _fornecedorId;
  final _freteController = TextEditingController(text: '0');
  final _descontoController = TextEditingController(text: '0');
  final _prazoController = TextEditingController();
  final _condicaoController = TextEditingController();
  late final List<TextEditingController> _valoresControllers;

  @override
  void initState() {
    super.initState();
    _valoresControllers = List.generate(
      widget.requisicao.itens.length,
      (_) => TextEditingController(text: '0'),
    );
  }

  @override
  void dispose() {
    _freteController.dispose();
    _descontoController.dispose();
    _prazoController.dispose();
    _condicaoController.dispose();
    for (final c in _valoresControllers) {
      c.dispose();
    }
    super.dispose();
  }

  double _parse(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.')) ?? 0;

  Future<void> _salvar() async {
    if (_fornecedorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escolha um fornecedor.')),
      );
      return;
    }

    final itens = <ItemCotacao>[
      for (var i = 0; i < widget.requisicao.itens.length; i++)
        ItemCotacao(
          descricao: widget.requisicao.itens[i].descricao,
          quantidade: widget.requisicao.itens[i].quantidade,
          unidade: widget.requisicao.itens[i].unidade,
          valorUnitario: _parse(_valoresControllers[i].text),
          materialCatalogoId: widget.requisicao.itens[i].materialCatalogoId,
        ),
    ];

    await _service.adicionarCotacao(
      requisicaoId: widget.requisicao.id,
      fornecedorId: _fornecedorId!,
      itens: itens,
      frete: _parse(_freteController.text),
      desconto: _parse(_descontoController.text),
      prazoEntrega: _prazoController.text.trim().isEmpty ? null : _prazoController.text.trim(),
      condicaoPagamento:
          _condicaoController.text.trim().isEmpty ? null : _condicaoController.text.trim(),
    );

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final fornecedores = _service.fornecedores(widget.orgId);

    return Scaffold(
      appBar: AppBar(title: Text('Cotação — ${widget.requisicao.codigo}')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _fornecedorId,
            decoration: const InputDecoration(labelText: 'Fornecedor'),
            items: fornecedores
                .map((f) => DropdownMenuItem(value: f.id, child: Text(f.nome)))
                .toList(),
            onChanged: (value) => setState(() => _fornecedorId = value),
          ),
          const SizedBox(height: 14),
          Text(
            'Valores por item',
            style: TextStyle(fontWeight: FontWeight.w800, color: appColors.textPrimary),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < widget.requisicao.itens.length; i++)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        '${widget.requisicao.itens[i].descricao}\n'
                        '${widget.requisicao.itens[i].quantidade} ${widget.requisicao.itens[i].unidade}',
                        style: TextStyle(color: appColors.textSecondary, fontSize: 12.5),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _valoresControllers[i],
                        decoration: const InputDecoration(labelText: 'Valor unit. (R\$)'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _freteController,
                  decoration: const InputDecoration(labelText: 'Frete (R\$)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _descontoController,
                  decoration: const InputDecoration(labelText: 'Desconto (R\$)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _prazoController,
            decoration: const InputDecoration(labelText: 'Prazo de entrega (opcional)'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _condicaoController,
            decoration: const InputDecoration(labelText: 'Condição de pagamento (opcional)'),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _salvar,
              icon: const Icon(Icons.check),
              label: const Text('Salvar cotação'),
            ),
          ),
        ],
      ),
    );
  }
}
