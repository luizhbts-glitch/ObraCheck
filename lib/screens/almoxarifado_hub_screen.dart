import 'package:flutter/material.dart';

import 'almoxarife_screen.dart';
import 'estoque_equipamentos_screen.dart';
import 'insumos_obra_screen.dart';

/// Hub do Almoxarifado — ponto de entrada único pras 3 áreas (saída de
/// equipamentos, estoque de equipamentos incluindo alugados, insumos de
/// obra). Antes disso, só dava pra chegar em Estoque/Insumos por um
/// ícone pequeno na AppBar do Controle de saída — pouco descobrível
/// (usuário achou que "equipamentos locados" não existia no app).
class AlmoxarifadoHubScreen extends StatelessWidget {
  const AlmoxarifadoHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Almoxarifado')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HubCard(
            icon: Icons.outbox_outlined,
            title: 'Controle de saída de equipamentos',
            subtitle: 'Quem pegou o quê, pendências de devolução e histórico',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AlmoxarifeScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          _HubCard(
            icon: Icons.inventory_2_outlined,
            title: 'Estoque de equipamentos',
            subtitle: 'Próprio, alugado (locados) e de terceiro',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EstoqueEquipamentosScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          _HubCard(
            icon: Icons.warehouse_outlined,
            title: 'Insumos de obra',
            subtitle: 'Estoque de material de consumo, com estoque mínimo e retirada rápida',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const InsumosObraScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  const _HubCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(icon, size: 32),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(subtitle),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
