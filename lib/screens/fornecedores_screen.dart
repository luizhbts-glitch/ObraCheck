import 'package:flutter/material.dart';

import '../services/compras_service.dart';
import '../theme/app_colors.dart';
import '../widgets/admin_ui.dart';

/// Compras > Fornecedores. Escopo por construtora (confirmado 2026-07-18):
/// um fornecedor de material atende várias obras da mesma construtora.
class FornecedoresScreen extends StatefulWidget {
  const FornecedoresScreen({super.key, required this.orgId});

  final String orgId;

  @override
  State<FornecedoresScreen> createState() => _FornecedoresScreenState();
}

class _FornecedoresScreenState extends State<FornecedoresScreen> {
  final ComprasService _service = ComprasService.instance;
  String _busca = '';

  Future<void> _novoFornecedor() async {
    final nomeController = TextEditingController();
    final categoriaController = TextEditingController();
    final cnpjController = TextEditingController();
    final telefoneController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.local_shipping_outlined),
        title: const Text('Novo fornecedor'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomeController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nome'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: categoriaController,
                decoration: const InputDecoration(
                  labelText: 'Categoria',
                  hintText: 'Ex.: Cimento, Material elétrico',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: cnpjController,
                decoration: const InputDecoration(labelText: 'CNPJ (opcional)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: telefoneController,
                decoration: const InputDecoration(labelText: 'Telefone (opcional)'),
                keyboardType: TextInputType.phone,
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

    if (result != true || nomeController.text.trim().isEmpty) return;
    await _service.criarFornecedor(
      orgId: widget.orgId,
      nome: nomeController.text,
      categoria: categoriaController.text,
      cnpj: cnpjController.text.trim().isEmpty ? null : cnpjController.text.trim(),
      telefone: telefoneController.text.trim().isEmpty ? null : telefoneController.text.trim(),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final todos = _service.fornecedores(widget.orgId);
    final termo = _busca.trim().toLowerCase();
    final filtrados = termo.isEmpty
        ? todos
        : todos
            .where((f) =>
                f.nome.toLowerCase().contains(termo) ||
                f.categoria.toLowerCase().contains(termo))
            .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Fornecedores')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _novoFornecedor,
        icon: const Icon(Icons.add),
        label: const Text('Novo fornecedor'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar por nome ou categoria',
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
                        icon: Icons.local_shipping_outlined,
                        message: todos.isEmpty
                            ? 'Nenhum fornecedor cadastrado ainda.'
                            : 'Nenhum fornecedor encontrado pra essa busca.',
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
                    itemCount: filtrados.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final fornecedor = filtrados[index];
                      return Card(
                        child: ListTile(
                          leading: InitialsAvatar(
                            label: fornecedor.nome,
                            background: appColors.selected.withValues(alpha: 0.14),
                            foreground: appColors.selected,
                          ),
                          title: Text(fornecedor.nome),
                          subtitle: Text(
                            [
                              if (fornecedor.categoria.isNotEmpty) fornecedor.categoria,
                              if (fornecedor.telefone?.isNotEmpty == true) fornecedor.telefone!,
                            ].join(' · '),
                          ),
                          trailing: fornecedor.categoria.isEmpty
                              ? null
                              : StatusBadge(
                                  label: fornecedor.categoria,
                                  color: appColors.selected,
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
