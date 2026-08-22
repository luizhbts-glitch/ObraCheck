import 'package:flutter/material.dart';

import '../models/equipamento_estoque_record.dart';
import '../services/equipamento_estoque_service.dart';
import '../services/project_context_service.dart';
import '../utils/equipamento_estoque_rules.dart';
import '../utils/text_case.dart';

/// Controle de estoque de equipamentos — separado do controle de
/// saída/devolução (`AlmoxarifeScreen`). Três categorias, especificadas
/// com o usuário em 2026-08-22: Próprio, Alugado e De terceiro.
class EstoqueEquipamentosScreen extends StatefulWidget {
  const EstoqueEquipamentosScreen({super.key});

  @override
  State<EstoqueEquipamentosScreen> createState() => _EstoqueEquipamentosScreenState();
}

class _EstoqueEquipamentosScreenState extends State<EstoqueEquipamentosScreen> {
  final EquipamentoEstoqueService _service = EquipamentoEstoqueService.instance;
  String _tab = TipoEquipamentoEstoque.proprio;

  String get _projectId => ProjectContextService.instance.currentProjectIdSync;

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _formatValor(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

  Future<void> _excluir(EquipamentoEstoqueRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir equipamento'),
        content: Text('Tem certeza que quer excluir "${record.material}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _service.excluir(record);
    if (mounted) setState(() {});
  }

  Future<void> _novoItem({String tipo = '', String? terceiroNomeFixo}) async {
    final efetivoTipo = tipo.isEmpty ? _tab : tipo;
    final materialCtrl = TextEditingController();
    final marcaCtrl = TextEditingController();
    final descricaoCtrl = TextEditingController();
    final locadoraCtrl = TextEditingController();
    final centroCustoCtrl = TextEditingController();
    final valorCtrl = TextEditingController();
    DateTime? periodoInicio;
    DateTime? periodoFim;
    String terceiroNome = terceiroNomeFixo ?? '';

    final terceirosConhecidos = _service.agruparPorTerceiro(_projectId).keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final titulo = switch (efetivoTipo) {
      TipoEquipamentoEstoque.alugado => 'Novo equipamento alugado',
      TipoEquipamentoEstoque.terceiro => 'Novo equipamento de terceiro',
      _ => 'Novo equipamento próprio',
    };

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialog) {
            return AlertDialog(
              title: Text(titulo),
              content: SizedBox(
                width: 380,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: materialCtrl,
                        autofocus: true,
                        decoration: const InputDecoration(labelText: 'Material *'),
                      ),
                      if (efetivoTipo != TipoEquipamentoEstoque.alugado) ...[
                        const SizedBox(height: 10),
                        TextField(
                          controller: marcaCtrl,
                          decoration: const InputDecoration(labelText: 'Marca'),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: descricaoCtrl,
                          decoration: const InputDecoration(labelText: 'Descrição'),
                        ),
                      ],
                      if (efetivoTipo == TipoEquipamentoEstoque.terceiro) ...[
                        const SizedBox(height: 10),
                        if (terceiroNomeFixo != null)
                          TextFormField(
                            initialValue: terceiroNomeFixo,
                            enabled: false,
                            decoration: const InputDecoration(labelText: 'Terceiro/Subcontratado *'),
                          )
                        else
                          Autocomplete<String>(
                            optionsMaxHeight: 180,
                            optionsBuilder: (v) {
                              final q = v.text.trim().toLowerCase();
                              if (q.isEmpty) return terceirosConhecidos;
                              return terceirosConhecidos.where((n) => n.toLowerCase().contains(q));
                            },
                            onSelected: (v) => setDialog(() => terceiroNome = v),
                            fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
                              return TextField(
                                controller: textController,
                                focusNode: focusNode,
                                decoration: const InputDecoration(labelText: 'Terceiro/Subcontratado *'),
                                onChanged: (v) => setDialog(() => terceiroNome = v),
                              );
                            },
                          ),
                      ],
                      if (efetivoTipo == TipoEquipamentoEstoque.alugado) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(periodoInicio == null ? 'Início *' : _formatDate(periodoInicio!)),
                                trailing: const Icon(Icons.calendar_today_outlined, size: 18),
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: dialogContext,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2100),
                                    initialDate: periodoInicio ?? DateTime.now(),
                                  );
                                  if (picked != null) setDialog(() => periodoInicio = picked);
                                },
                              ),
                            ),
                            Expanded(
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(periodoFim == null ? 'Fim *' : _formatDate(periodoFim!)),
                                trailing: const Icon(Icons.calendar_today_outlined, size: 18),
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: dialogContext,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2100),
                                    initialDate: periodoFim ?? periodoInicio ?? DateTime.now(),
                                  );
                                  if (picked != null) setDialog(() => periodoFim = picked);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: locadoraCtrl,
                          decoration: const InputDecoration(labelText: 'Locadora *'),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: centroCustoCtrl,
                          decoration: const InputDecoration(labelText: 'Centro de custo *'),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: valorCtrl,
                          decoration: const InputDecoration(labelText: 'Valor (R\$) *'),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
                FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Salvar')),
              ],
            );
          },
        );
      },
    );

    if (ok != true) return;

    final valor = double.tryParse(valorCtrl.text.trim().replaceAll(',', '.'));
    final erro = validarCamposEquipamentoEstoque(
      tipo: efetivoTipo,
      material: materialCtrl.text,
      terceiroNome: terceiroNome,
      periodoInicio: periodoInicio,
      periodoFim: periodoFim,
      locadora: locadoraCtrl.text,
      centroCusto: centroCustoCtrl.text,
      valor: valor,
    );
    if (erro != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro)));
      }
      return;
    }

    await _service.criar(
      projectId: _projectId,
      tipo: efetivoTipo,
      material: toSentenceCase(materialCtrl.text),
      marca: marcaCtrl.text.trim().isEmpty ? null : toSentenceCase(marcaCtrl.text),
      descricao: descricaoCtrl.text.trim().isEmpty ? null : descricaoCtrl.text.trim(),
      terceiroNome: terceiroNome.trim().isEmpty ? null : toSentenceCase(terceiroNome),
      periodoInicio: periodoInicio,
      periodoFim: periodoFim,
      locadora: locadoraCtrl.text.trim().isEmpty ? null : locadoraCtrl.text.trim(),
      centroCusto: centroCustoCtrl.text.trim().isEmpty ? null : centroCustoCtrl.text.trim(),
      valor: valor,
    );

    if (mounted) setState(() {});
  }

  Future<void> _abrirTerceiro(String nome, List<EquipamentoEstoqueRecord> itens) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheet) {
            final atuais = _service.agruparPorTerceiro(_projectId)[nome] ?? const <EquipamentoEstoqueRecord>[];
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(sheetContext).size.height * 0.72,
                child: Column(
                  children: [
                    ListTile(
                      title: Text('$nome (${atuais.length})', style: const TextStyle(fontWeight: FontWeight.w800)),
                      trailing: FilledButton.icon(
                        onPressed: () async {
                          await _novoItem(tipo: TipoEquipamentoEstoque.terceiro, terceiroNomeFixo: nome);
                          setSheet(() {});
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Equipamento'),
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: atuais.isEmpty
                          ? const Center(child: Text('Nenhum equipamento cadastrado ainda.'))
                          : ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: atuais.length,
                              separatorBuilder: (_, unused) => const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                final item = atuais[i];
                                return Card(
                                  child: ListTile(
                                    title: Text(item.material),
                                    subtitle: Text(
                                      [
                                        if ((item.marca ?? '').isNotEmpty) 'Marca: ${item.marca}',
                                        if ((item.descricao ?? '').isNotEmpty) item.descricao!,
                                      ].join(' • '),
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () async {
                                        await _excluir(item);
                                        setSheet(() {});
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (mounted) setState(() {});
  }

  Widget _buildProprioOuTerceiroCard(EquipamentoEstoqueRecord item) {
    return Card(
      child: ListTile(
        title: Text(item.material),
        subtitle: Text(
          [
            if ((item.marca ?? '').isNotEmpty) 'Marca: ${item.marca}',
            if ((item.descricao ?? '').isNotEmpty) item.descricao!,
          ].join(' • '),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _excluir(item),
        ),
      ),
    );
  }

  Widget _buildAlugadoCard(EquipamentoEstoqueRecord item) {
    return Card(
      child: ListTile(
        title: Text(item.material),
        subtitle: Text(
          'Período: ${item.periodoInicio != null ? _formatDate(item.periodoInicio!) : '-'} a '
          '${item.periodoFim != null ? _formatDate(item.periodoFim!) : '-'}\n'
          'Locadora: ${item.locadora ?? '-'} • Centro de custo: ${item.centroCusto ?? '-'}\n'
          'Valor: ${item.valor != null ? _formatValor(item.valor!) : '-'}',
        ),
        isThreeLine: true,
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _excluir(item),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final projectId = _projectId;

    return Scaffold(
      appBar: AppBar(title: const Text('Estoque de equipamentos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _novoItem(),
        icon: const Icon(Icons.add),
        label: Text(_tab == TipoEquipamentoEstoque.terceiro ? 'Terceiro/equipamento' : 'Adicionar'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Próprio'),
                  selected: _tab == TipoEquipamentoEstoque.proprio,
                  onSelected: (_) => setState(() => _tab = TipoEquipamentoEstoque.proprio),
                ),
                ChoiceChip(
                  label: const Text('Alugado'),
                  selected: _tab == TipoEquipamentoEstoque.alugado,
                  onSelected: (_) => setState(() => _tab = TipoEquipamentoEstoque.alugado),
                ),
                ChoiceChip(
                  label: const Text('De terceiro'),
                  selected: _tab == TipoEquipamentoEstoque.terceiro,
                  onSelected: (_) => setState(() => _tab = TipoEquipamentoEstoque.terceiro),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: switch (_tab) {
                TipoEquipamentoEstoque.alugado => Builder(
                    builder: (context) {
                      final itens = _service.porTipo(projectId, TipoEquipamentoEstoque.alugado);
                      if (itens.isEmpty) {
                        return const Center(child: Text('Nenhum equipamento alugado cadastrado.'));
                      }
                      return ListView.separated(
                        itemCount: itens.length,
                        separatorBuilder: (_, unused) => const SizedBox(height: 8),
                        itemBuilder: (context, i) => _buildAlugadoCard(itens[i]),
                      );
                    },
                  ),
                TipoEquipamentoEstoque.terceiro => Builder(
                    builder: (context) {
                      final grupos = _service.agruparPorTerceiro(projectId);
                      final nomes = grupos.keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
                      if (nomes.isEmpty) {
                        return const Center(child: Text('Nenhum terceiro com equipamento cadastrado.'));
                      }
                      return ListView.separated(
                        itemCount: nomes.length,
                        separatorBuilder: (_, unused) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final nome = nomes[i];
                          final itens = grupos[nome]!;
                          return Card(
                            child: ListTile(
                              title: Text(nome),
                              subtitle: Text('${itens.length} equipamento(s)'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _abrirTerceiro(nome, itens),
                            ),
                          );
                        },
                      );
                    },
                  ),
                _ => Builder(
                    builder: (context) {
                      final itens = _service.porTipo(projectId, TipoEquipamentoEstoque.proprio);
                      if (itens.isEmpty) {
                        return const Center(child: Text('Nenhum equipamento próprio cadastrado.'));
                      }
                      return ListView.separated(
                        itemCount: itens.length,
                        separatorBuilder: (_, unused) => const SizedBox(height: 8),
                        itemBuilder: (context, i) => _buildProprioOuTerceiroCard(itens[i]),
                      );
                    },
                  ),
              },
            ),
          ],
        ),
      ),
    );
  }
}
