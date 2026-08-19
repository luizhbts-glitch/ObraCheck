import 'package:flutter/material.dart';

import '../services/project_context_service.dart';
import '../theme/app_colors.dart';
import '../widgets/admin_ui.dart';
import 'fornecedores_screen.dart';
import 'materiais_screen.dart';
import 'pedidos_compra_screen.dart';
import 'requisicoes_screen.dart';

/// Módulo Compras completo — prévia funcional antes do menu lateral
/// definitivo (Fase 1a do plano ERP) existir. Quando o menu lateral for
/// construído, estes 4 cartões viram sub-itens dele.
class ComprasHomeScreen extends StatelessWidget {
  const ComprasHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final orgId = ProjectContextService.instance.currentProject?.orgId ?? '';

    if (orgId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Compras')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: EmptyStateHint(
              icon: Icons.business_outlined,
              message:
                  'Esta obra ainda não está vinculada a uma construtora.\nVincule em Painel de controle > Construtoras antes de usar Compras.',
            ),
          ),
        ),
      );
    }

    final itens = <_ComprasMenuItem>[
      _ComprasMenuItem(
        icon: Icons.assignment_outlined,
        titulo: 'Requisições',
        subtitulo: 'Quadro por status, do pedido inicial até a cotação',
        cor: appColors.warning,
        builder: (_) => RequisicoesScreen(orgId: orgId),
      ),
      _ComprasMenuItem(
        icon: Icons.receipt_long_outlined,
        titulo: 'Ordem de compra',
        subtitulo: 'Pedidos aprovados, recebimento e saldo',
        cor: appColors.selected,
        builder: (_) => PedidosCompraScreen(orgId: orgId),
      ),
      _ComprasMenuItem(
        icon: Icons.local_shipping_outlined,
        titulo: 'Fornecedores',
        subtitulo: 'Cadastro por construtora',
        cor: appColors.success,
        builder: (_) => FornecedoresScreen(orgId: orgId),
      ),
      _ComprasMenuItem(
        icon: Icons.inventory_2_outlined,
        titulo: 'Materiais',
        subtitulo: 'Catálogo mestre de produtos',
        cor: appColors.primaryAction,
        builder: (_) => MateriaisScreen(orgId: orgId),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Compras')),
      body: ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: itens.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = itens[index];
          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: item.builder),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: item.cor.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(item.icon, color: item.cor),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.titulo,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15.5,
                              color: appColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.subtitulo,
                            style: TextStyle(fontSize: 12.5, color: appColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: appColors.textSecondary),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ComprasMenuItem {
  const _ComprasMenuItem({
    required this.icon,
    required this.titulo,
    required this.subtitulo,
    required this.cor,
    required this.builder,
  });

  final IconData icon;
  final String titulo;
  final String subtitulo;
  final Color cor;
  final WidgetBuilder builder;
}
