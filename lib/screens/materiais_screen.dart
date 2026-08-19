import 'package:flutter/material.dart';

import '../services/compras_service.dart';
import '../theme/app_colors.dart';
import '../widgets/admin_ui.dart';

/// Compras > Materiais — catálogo mestre confirmado contra o sistema de
/// referência (L7) em 2026-07-18. Requisições selecionam itens daqui em
/// vez de digitar tudo em texto livre.
class MateriaisScreen extends StatefulWidget {
  const MateriaisScreen({super.key, required this.orgId});

  final String orgId;

  @override
  State<MateriaisScreen> createState() => _MateriaisScreenState();
}

class _MateriaisScreenState extends State<MateriaisScreen> {
  final ComprasService _service = ComprasService.instance;
  String _busca = '';

  Future<void> _novoMaterial() async {
    final produtoController = TextEditingController();
    final categoriaController = TextEditingController();
    final unidadeController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.inventory_2_outlined),
        title: const Text('Novo material'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: produtoController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Produto'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: categoriaController,
                decoration: const InputDecoration(
                  labelText: 'Categoria',
                  hintText: 'Ex.: Material elétrico',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: unidadeController,
                decoration: const InputDecoration(
                  labelText: 'Unidade',
                  hintText: 'Ex.: UN, m², saco',
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
            child: const Text('Criar'),
          ),
        ],
      ),
    );

    if (result != true || produtoController.text.trim().isEmpty) return;
    await _service.criarMaterial(
      orgId: widget.orgId,
      produto: produtoController.text,
      categoria: categoriaController.text,
      unidadeMedida: unidadeController.text,
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final todos = _service.materiaisCatalogo(widget.orgId);
    final termo = _busca.trim().toLowerCase();
    final filtrados = termo.isEmpty
        ? todos
        : todos
            .where((m) =>
                m.produto.toLowerCase().contains(termo) ||
                m.categoria.toLowerCase().contains(termo))
            .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Materiais')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _novoMaterial,
        icon: const Icon(Icons.add),
        label: const Text('Novo material'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar por produto ou categoria',
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
                        icon: Icons.inventory_2_outlined,
                        message: todos.isEmpty
                            ? 'Nenhum material cadastrado ainda.'
                            : 'Nenhum material encontrado pra essa busca.',
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
                    itemCount: filtrados.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final material = filtrados[index];
                      final custo = material.custoMedioReferencia;
                      final subtitleParts = <String>[
                        if (material.categoria.isNotEmpty) material.categoria,
                        if (material.unidadeMedida.isNotEmpty) material.unidadeMedida,
                        if (custo != null) 'Ref.: R\$ ${custo.toStringAsFixed(2)}',
                      ];
                      return Card(
                        child: ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: appColors.warning.withValues(alpha: 0.14),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.inventory_2_outlined, color: appColors.warning),
                          ),
                          title: Text(material.produto),
                          subtitle: Text(subtitleParts.join(' · ')),
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
