import 'package:flutter/material.dart';

import '../models/insumo_obra_record.dart';
import '../services/insumo_obra_service.dart';
import '../services/project_context_service.dart';
import '../theme/app_colors.dart';
import '../utils/insumo_rules.dart';
import '../utils/text_case.dart';

/// Controle de insumos de obra — planilha simples de estoque de material
/// de consumo, separada do fluxo formal de Compras. Especificado com o
/// usuário em 2026-08-22: material + endereço, estoque mínimo (alerta
/// visual) e retirada informal (sem aprovação), com histórico filtrável.
class InsumosObraScreen extends StatefulWidget {
  const InsumosObraScreen({super.key});

  @override
  State<InsumosObraScreen> createState() => _InsumosObraScreenState();
}

class _InsumosObraScreenState extends State<InsumosObraScreen> {
  final InsumoObraService _service = InsumoObraService.instance;
  String _tab = 'estoque';
  final TextEditingController _historicoSearchCtrl = TextEditingController();

  String get _projectId => ProjectContextService.instance.currentProjectIdSync;

  @override
  void dispose() {
    _historicoSearchCtrl.dispose();
    super.dispose();
  }

  String _formatQty(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2).replaceAll('.', ',');
  }

  String _formatDateTime(DateTime v) {
    return '${v.day.toString().padLeft(2, '0')}/${v.month.toString().padLeft(2, '0')}/${v.year} '
        '${v.hour.toString().padLeft(2, '0')}:${v.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _novoInsumo() async {
    final materialCtrl = TextEditingController();
    final enderecoCtrl = TextEditingController();
    final minimoCtrl = TextEditingController(text: '0');
    final inicialCtrl = TextEditingController(text: '0');
    String unidade = UnidadeMedida.unidade;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Novo insumo'),
          content: SizedBox(
            width: 380,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: materialCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Material *'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: enderecoCtrl,
                    decoration: const InputDecoration(labelText: 'Endereço (local no almoxarifado)'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: unidade,
                    decoration: const InputDecoration(labelText: 'Unidade de medida'),
                    items: UnidadeMedida.todas
                        .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setDialog(() => unidade = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: minimoCtrl,
                    decoration: const InputDecoration(labelText: 'Estoque mínimo'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: inicialCtrl,
                    decoration: const InputDecoration(labelText: 'Estoque inicial'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Salvar')),
          ],
        ),
      ),
    );

    if (ok != true) return;

    final estoqueMinimo = double.tryParse(minimoCtrl.text.trim().replaceAll(',', '.')) ?? 0;
    final quantidadeInicial = double.tryParse(inicialCtrl.text.trim().replaceAll(',', '.')) ?? 0;
    final erro = validarNovoInsumo(
      material: materialCtrl.text,
      estoqueMinimo: estoqueMinimo,
      quantidadeInicial: quantidadeInicial,
    );
    if (erro != null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro)));
      return;
    }

    await _service.criar(
      projectId: _projectId,
      material: toSentenceCase(materialCtrl.text),
      endereco: enderecoCtrl.text.trim(),
      estoqueMinimo: estoqueMinimo,
      quantidadeInicial: quantidadeInicial,
      unidade: unidade,
    );
    if (mounted) setState(() {});
  }

  Future<void> _retirar(InsumoObraRecord insumo) async {
    final qtdCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Retirar — ${insumo.material}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Estoque atual: ${_formatQty(insumo.quantidadeAtual)} ${insumo.unidade}'),
            const SizedBox(height: 12),
            TextField(
              controller: qtdCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Quantidade retirada'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Retirar')),
        ],
      ),
    );

    if (ok != true) return;

    final quantidade = double.tryParse(qtdCtrl.text.trim().replaceAll(',', '.')) ?? 0;
    final erro = validarRetiradaInsumo(
      quantidadeAtual: insumo.quantidadeAtual,
      quantidadeRetirada: quantidade,
    );
    if (erro != null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro)));
      return;
    }

    await _service.retirar(insumo, quantidade);
    if (mounted) setState(() {});
  }

  Future<void> _atualizarContagem(InsumoObraRecord insumo) async {
    final qtdCtrl = TextEditingController(text: _formatQty(insumo.quantidadeAtual));

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Atualizar contagem — ${insumo.material}'),
        content: TextField(
          controller: qtdCtrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nova quantidade em estoque'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Salvar')),
        ],
      ),
    );

    if (ok != true) return;

    final novaQuantidade = double.tryParse(qtdCtrl.text.trim().replaceAll(',', '.'));
    if (novaQuantidade == null || novaQuantidade < 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quantidade inválida.')),
        );
      }
      return;
    }

    await _service.atualizarContagem(insumo, novaQuantidade);
    if (mounted) setState(() {});
  }

  Future<void> _editar(InsumoObraRecord insumo) async {
    final materialCtrl = TextEditingController(text: insumo.material);
    final enderecoCtrl = TextEditingController(text: insumo.endereco);
    final minimoCtrl = TextEditingController(text: _formatQty(insumo.estoqueMinimo));
    String unidade = insumo.unidade;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Editar insumo'),
          content: SizedBox(
            width: 380,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: materialCtrl, decoration: const InputDecoration(labelText: 'Material *')),
                  const SizedBox(height: 10),
                  TextField(controller: enderecoCtrl, decoration: const InputDecoration(labelText: 'Endereço')),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: unidade,
                    decoration: const InputDecoration(labelText: 'Unidade de medida'),
                    items: UnidadeMedida.todas
                        .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setDialog(() => unidade = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: minimoCtrl,
                    decoration: const InputDecoration(labelText: 'Estoque mínimo'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Salvar')),
          ],
        ),
      ),
    );

    if (ok != true) return;

    final estoqueMinimo = double.tryParse(minimoCtrl.text.trim().replaceAll(',', '.')) ?? 0;
    final erro = validarNovoInsumo(material: materialCtrl.text, estoqueMinimo: estoqueMinimo);
    if (erro != null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro)));
      return;
    }

    await _service.editar(
      insumo,
      material: toSentenceCase(materialCtrl.text),
      endereco: enderecoCtrl.text.trim(),
      estoqueMinimo: estoqueMinimo,
      unidade: unidade,
    );
    if (mounted) setState(() {});
  }

  Future<void> _conferir(PendenciaConferencia pendencia) async {
    final insumo = pendencia.insumo;
    final qtdCtrl = TextEditingController();
    final obsCtrl = TextEditingController();
    double? divergenciaAtual;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) {
          return AlertDialog(
            title: Text('Conferir — ${insumo.material}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sistema espera: ${_formatQty(insumo.quantidadeAtual)} ${insumo.unidade}\n'
                    'Retirado desde a última conferência: '
                    '${_formatQty(pendencia.quantidadeRetiradaPendente)} ${insumo.unidade} '
                    '(última em ${_formatDateTime(pendencia.ultimaRetiradaEm)})',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: qtdCtrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Quantidade contada agora (${insumo.unidade})',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) {
                      final contada = double.tryParse(value.trim().replaceAll(',', '.'));
                      setDialog(() {
                        divergenciaAtual = contada == null
                            ? null
                            : calcularDivergenciaConferencia(
                                quantidadeEsperada: insumo.quantidadeAtual,
                                quantidadeConferida: contada,
                              );
                      });
                    },
                  ),
                  if (divergenciaAtual != null && divergenciaAtual != 0) ...[
                    const SizedBox(height: 12),
                    Text(
                      divergenciaAtual! > 0
                          ? 'Sobra de ${_formatQty(divergenciaAtual!.abs())} ${insumo.unidade}'
                          : 'Falta de ${_formatQty(divergenciaAtual!.abs())} ${insumo.unidade}',
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: obsCtrl,
                      minLines: 2,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'O que aconteceu? *',
                        hintText: 'Ex.: estava de atestado, outra pessoa cobriu.',
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmar')),
            ],
          );
        },
      ),
    );

    if (ok != true) return;

    final quantidadeConferida = double.tryParse(qtdCtrl.text.trim().replaceAll(',', '.'));
    if (quantidadeConferida == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Informe a quantidade contada.')),
        );
      }
      return;
    }

    final divergencia = calcularDivergenciaConferencia(
      quantidadeEsperada: insumo.quantidadeAtual,
      quantidadeConferida: quantidadeConferida,
    );
    final erro = validarConferenciaInsumo(
      quantidadeConferida: quantidadeConferida,
      divergencia: divergencia,
      observacao: obsCtrl.text,
    );
    if (erro != null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro)));
      return;
    }

    await _service.registrarConferencia(
      insumo: insumo,
      quantidadeConferida: quantidadeConferida,
      observacao: obsCtrl.text,
    );
    if (mounted) setState(() {});
  }

  Future<void> _excluir(InsumoObraRecord insumo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir insumo'),
        content: Text('Tem certeza que quer excluir "${insumo.material}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _service.excluir(insumo);
    if (mounted) setState(() {});
  }

  Widget _buildInsumoCard(InsumoObraRecord insumo, AppColors appColors) {
    final abaixoDoMinimo = insumo.abaixoDoMinimo;
    return Card(
      color: abaixoDoMinimo ? appColors.warning.withValues(alpha: 0.14) : null,
      child: ListTile(
        title: Row(
          children: [
            Flexible(child: Text(insumo.material)),
            if (abaixoDoMinimo) ...[
              const SizedBox(width: 6),
              Icon(Icons.warning_amber_rounded, size: 16, color: appColors.warning),
            ],
          ],
        ),
        subtitle: Text(
          '${insumo.endereco.isEmpty ? 'Sem endereço definido' : 'Endereço: ${insumo.endereco}'}\n'
          'Estoque: ${_formatQty(insumo.quantidadeAtual)} ${insumo.unidade} '
          '(mín.: ${_formatQty(insumo.estoqueMinimo)} ${insumo.unidade})'
          '${abaixoDoMinimo ? ' • Abaixo do mínimo' : ''}',
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(onPressed: () => _retirar(insumo), child: const Text('Retirar')),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'contagem':
                    _atualizarContagem(insumo);
                  case 'editar':
                    _editar(insumo);
                  case 'excluir':
                    _excluir(insumo);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'contagem', child: Text('Atualizar contagem')),
                PopupMenuItem(value: 'editar', child: Text('Editar')),
                PopupMenuItem(value: 'excluir', child: Text('Excluir')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _tipoMovimentoLabel(String tipo) {
    return tipo == TipoMovimentoInsumo.retirada ? 'Retirada' : 'Ajuste de contagem';
  }

  Widget _buildMovimentoCard(InsumoMovimentoRecord m) {
    final isRetirada = m.tipo == TipoMovimentoInsumo.retirada;
    final sinal = isRetirada ? '-' : (m.quantidade >= 0 ? '+' : '');
    return Card(
      child: ListTile(
        title: Text(m.material),
        subtitle: Text(
          '${_tipoMovimentoLabel(m.tipo)}: $sinal${_formatQty(m.quantidade.abs())} '
          '• Saldo após: ${_formatQty(m.saldoResultante)}\n${_formatDateTime(m.createdAt)}',
        ),
      ),
    );
  }

  Widget _buildPendenciaCard(PendenciaConferencia pendencia, AppColors appColors) {
    final insumo = pendencia.insumo;
    return Card(
      color: appColors.warning.withValues(alpha: 0.14),
      child: ListTile(
        leading: Icon(Icons.fact_check_outlined, color: appColors.warning),
        title: Text(insumo.material),
        subtitle: Text(
          'Retirado ${_formatQty(pendencia.quantidadeRetiradaPendente)} ${insumo.unidade} '
          'desde a última conferência (última retirada em '
          '${_formatDateTime(pendencia.ultimaRetiradaEm)})\n'
          'Sistema espera: ${_formatQty(insumo.quantidadeAtual)} ${insumo.unidade}',
        ),
        isThreeLine: true,
        trailing: FilledButton(
          onPressed: () => _conferir(pendencia),
          child: const Text('Conferir'),
        ),
      ),
    );
  }

  Widget _buildConferenciaCard(InsumoConferenciaRecord c) {
    return Card(
      color: c.temDivergencia ? Colors.red.withValues(alpha: 0.08) : null,
      child: ListTile(
        leading: Icon(
          c.temDivergencia ? Icons.error_outline : Icons.check_circle_outline,
          color: c.temDivergencia ? Colors.red : Colors.green,
        ),
        title: Text(c.material),
        subtitle: Text(
          'Esperado: ${_formatQty(c.quantidadeEsperada)} ${c.unidade} • '
          'Contado: ${_formatQty(c.quantidadeConferida)} ${c.unidade}'
          '${c.temDivergencia ? ' • ${c.divergencia > 0 ? 'Sobra' : 'Falta'} de ${_formatQty(c.divergencia.abs())} ${c.unidade}' : ' • Bateu certinho'}'
          '${c.observacao != null ? '\nOcorrência: ${c.observacao}' : ''}'
          '\n${_formatDateTime(c.createdAt)}',
        ),
        isThreeLine: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final projectId = _projectId;

    return Scaffold(
      appBar: AppBar(title: const Text('Insumos de obra')),
      floatingActionButton: _tab == 'estoque'
          ? FloatingActionButton.extended(
              onPressed: _novoInsumo,
              icon: const Icon(Icons.add),
              label: const Text('Novo insumo'),
            )
          : null,
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Builder(
              builder: (context) {
                final pendencias = _service.pendenciasDeConferencia(projectId);
                return Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Estoque'),
                      selected: _tab == 'estoque',
                      onSelected: (_) => setState(() => _tab = 'estoque'),
                    ),
                    ChoiceChip(
                      label: Text(
                        pendencias.isEmpty ? 'Conferência' : 'Conferência (${pendencias.length})',
                      ),
                      selected: _tab == 'conferencia',
                      onSelected: (_) => setState(() => _tab = 'conferencia'),
                    ),
                    ChoiceChip(
                      label: const Text('Histórico'),
                      selected: _tab == 'historico',
                      onSelected: (_) => setState(() => _tab = 'historico'),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            Expanded(
              child: switch (_tab) {
                'conferencia' => Builder(
                    builder: (context) {
                      final pendencias = _service.pendenciasDeConferencia(projectId);
                      final registradas = _service.historicoConferencias(projectId);
                      if (pendencias.isEmpty && registradas.isEmpty) {
                        return const Center(
                          child: Text('Nenhuma retirada pendente de conferência ainda.'),
                        );
                      }
                      return ListView(
                        children: [
                          if (pendencias.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                'Pendentes',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                            for (final p in pendencias) ...[
                              _buildPendenciaCard(p, appColors),
                              const SizedBox(height: 8),
                            ],
                            const SizedBox(height: 8),
                          ],
                          if (registradas.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                'Conferências registradas',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                            for (final c in registradas) ...[
                              _buildConferenciaCard(c),
                              const SizedBox(height: 8),
                            ],
                          ],
                        ],
                      );
                    },
                  ),
                'historico' => Column(
                    children: [
                      TextField(
                        controller: _historicoSearchCtrl,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Filtrar por material',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final movimentos = _service.historico(
                              projectId,
                              material: _historicoSearchCtrl.text,
                            );
                            if (movimentos.isEmpty) {
                              return const Center(child: Text('Nenhum movimento encontrado.'));
                            }
                            return ListView.separated(
                              itemCount: movimentos.length,
                              separatorBuilder: (_, unused) => const SizedBox(height: 8),
                              itemBuilder: (context, i) => _buildMovimentoCard(movimentos[i]),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                _ => Builder(
                    builder: (context) {
                      final itens = _service.listar(projectId);
                      if (itens.isEmpty) {
                        return const Center(child: Text('Nenhum insumo cadastrado ainda.'));
                      }
                      return ListView.separated(
                        itemCount: itens.length,
                        separatorBuilder: (_, unused) => const SizedBox(height: 8),
                        itemBuilder: (context, i) => _buildInsumoCard(itens[i], appColors),
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
