import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../data/arsen_structure.dart';
import '../data/fvs_catalog.dart';
import '../models/company_record.dart';
import '../models/medicao_campo_record.dart';
import '../services/medicao_campo_service.dart';
import '../services/project_context_service.dart';
import '../utils/medicao_campo_rules.dart';
import '../utils/project_scope.dart';
import 'company_form_screen.dart';

/// Nova medição (ou edição dos dados e da seleção de aptos de uma existente):
/// serviço, empreiteiro, pasta (ano/mês), período e a grade onde se marcam os
/// apartamentos pagos nesta medição — multi-seleção, com "todos do andar".
/// Devolve o [MedicaoCampoRecord] salvo.
class MedicaoCampoFormScreen extends StatefulWidget {
  const MedicaoCampoFormScreen({
    super.key,
    this.existing,
    this.initialAno,
    this.initialMes,
    this.initialEmpresa,
  });

  final MedicaoCampoRecord? existing;
  final int? initialAno;
  final int? initialMes;
  final CompanyRecord? initialEmpresa;

  @override
  State<MedicaoCampoFormScreen> createState() => _MedicaoCampoFormScreenState();
}

class _MedicaoCampoFormScreenState extends State<MedicaoCampoFormScreen> {
  final ProjectContextService _projectContext = ProjectContextService.instance;
  final TextEditingController _periodoController = TextEditingController();

  String _servicoCodigo = '';
  String _servicoNome = '';
  String _empId = '';
  String _empNome = '';
  late int _ano;
  late int _mes;
  late String _torre;
  final Map<String, MedicaoCampoApto> _sel = <String, MedicaoCampoApto>{};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final existing = widget.existing;
    _ano = existing?.ano ?? widget.initialAno ?? now.year;
    _mes = existing?.mes ?? widget.initialMes ?? now.month;
    final torres = ObraStructure.torres;
    _torre = torres.isNotEmpty ? torres.first : '';
    if (existing != null) {
      _servicoCodigo = existing.servicoCodigo;
      _servicoNome = existing.servicoNome;
      _empId = existing.empreiteiroId;
      _empNome = existing.empreiteiroNome;
      _periodoController.text = existing.periodo;
      for (final a in existing.aptos) {
        _sel[a.chave] = a;
      }
      if (existing.aptos.isNotEmpty && torres.contains(existing.aptos.first.torre)) {
        _torre = existing.aptos.first.torre;
      }
    } else if (widget.initialEmpresa != null) {
      _setEmpresa(widget.initialEmpresa!);
    }
  }

  @override
  void dispose() {
    _periodoController.dispose();
    super.dispose();
  }

  void _setEmpresa(CompanyRecord c) {
    _empId = c.id;
    _empNome = rotuloEmpreiteiro(especialidade: c.especialidade, nome: c.nome);
  }

  Future<void> _pickServico() async {
    final picked = await showModalBottomSheet<FvsTemplate>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setSheet) {
            final q = query.trim().toLowerCase();
            final lista = FvsCatalog.all.where((t) {
              if (q.isEmpty) return true;
              return t.nome.toLowerCase().contains(q) ||
                  t.codigo.toLowerCase().contains(q) ||
                  t.profissao.toLowerCase().contains(q);
            }).toList();
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.75,
                  child: Column(
                    children: [
                      const ListTile(
                        title: Text(
                          'Escolher serviço',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: TextField(
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'Buscar',
                          ),
                          onChanged: (v) => setSheet(() => query = v),
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          children: lista
                              .map(
                                (t) => ListTile(
                                  title: Text('${t.codigo} • ${t.nome}'),
                                  subtitle: Text(t.profissao),
                                  onTap: () => Navigator.pop(context, t),
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    if (picked == null) return;
    setState(() {
      _servicoCodigo = picked.codigo;
      _servicoNome = picked.nome;
    });
  }

  Future<void> _pickEmpreiteiro() async {
    final box = Hive.box<CompanyRecord>('companies');
    final projectId = _projectContext.currentProjectIdSync;
    final picked = await showModalBottomSheet<CompanyRecord>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setSheet) {
            final todas = filterRecordsByProjectScope(
              box.values.where((c) => !c.deleted),
              currentProjectId: projectId,
              projectId: (c) => c.projectId,
            ).toList()
              ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
            final q = query.trim().toLowerCase();
            final lista = todas.where((c) {
              if (q.isEmpty) return true;
              return c.nome.toLowerCase().contains(q) ||
                  c.especialidade.toLowerCase().contains(q);
            }).toList();
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.72,
                  child: Column(
                    children: [
                      ListTile(
                        title: const Text(
                          'Escolher empreiteiro',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        trailing: TextButton.icon(
                          onPressed: () async {
                            final nova = await showCompanyFormDialog(
                              context: sheetContext,
                              box: box,
                            );
                            if (nova != null && sheetContext.mounted) {
                              Navigator.pop(sheetContext, nova);
                            }
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Novo'),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: TextField(
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'Buscar',
                          ),
                          onChanged: (v) => setSheet(() => query = v),
                        ),
                      ),
                      Expanded(
                        child: lista.isEmpty
                            ? const Center(child: Text('Nenhum empreiteiro.'))
                            : ListView(
                                children: lista
                                    .map(
                                      (c) => ListTile(
                                        title: Text(
                                          rotuloEmpreiteiro(
                                            especialidade: c.especialidade,
                                            nome: c.nome,
                                          ),
                                        ),
                                        onTap: () => Navigator.pop(context, c),
                                      ),
                                    )
                                    .toList(growable: false),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    if (picked == null) return;
    setState(() => _setEmpresa(picked));
  }

  List<OperationalGridCell> _cellsDaTorre() {
    return ObraStructure.operationalCellsForTower(
      _torre,
    ).where((c) => !c.isSpecialArea).toList(growable: false);
  }

  MedicaoCampoApto _novoApto(OperationalGridCell c) => MedicaoCampoApto(
    torre: _torre,
    localRef: c.localRef,
    label: c.label,
    andar: c.andar,
  );

  String _chave(OperationalGridCell c) => '$_torre|${c.localRef}';

  void _toggleCell(OperationalGridCell c) {
    setState(() {
      final key = _chave(c);
      if (_sel.containsKey(key)) {
        _sel.remove(key);
      } else {
        _sel[key] = _novoApto(c);
      }
    });
  }

  void _setCells(Iterable<OperationalGridCell> cells, bool selecionar) {
    setState(() {
      for (final c in cells) {
        final key = _chave(c);
        if (selecionar) {
          _sel.putIfAbsent(key, () => _novoApto(c));
        } else {
          _sel.remove(key);
        }
      }
    });
  }

  int _selecionadosNaTorre(String torre) =>
      _sel.values.where((a) => a.torre == torre).length;

  Future<void> _save() async {
    final erro = validarNovaMedicao(
      servicoCodigo: _servicoCodigo,
      empreiteiroNome: _empNome,
      totalAptosSelecionados: _sel.length,
    );
    if (erro != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro)));
      return;
    }

    final existing = widget.existing;
    if (existing != null) {
      final perdidos = existing.aptos
          .where((a) => !_sel.containsKey(a.chave) && a.fotos.isNotEmpty)
          .toList();
      if (perdidos.isNotEmpty) {
        final fotos = perdidos.fold<int>(0, (t, a) => t + a.fotos.length);
        final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Remover apartamentos com fotos?'),
            content: Text(
              '${perdidos.length} apartamento(s) desmarcado(s) têm $fotos foto(s) '
              'que serão removidas da medição.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Voltar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Remover'),
              ),
            ],
          ),
        );
        if (ok != true) return;
      }
    }

    setState(() => _saving = true);
    try {
      final service = MedicaoCampoService.instance;
      final aptos = _sel.values.toList()..sort(compararAptosMedicao);
      final MedicaoCampoRecord saved;
      if (existing == null) {
        final usuario = await service.resolverNomeUsuario();
        saved = await service.criar(
          projectId: _projectContext.currentProjectIdSync,
          obra: _projectContext.currentProjectNameSync,
          servicoCodigo: _servicoCodigo,
          servicoNome: _servicoNome,
          empreiteiroId: _empId,
          empreiteiroNome: _empNome,
          periodo: _periodoController.text,
          responsavelNome: usuario,
          ano: _ano,
          mes: _mes,
          aptos: aptos,
        );
      } else {
        saved = await service.salvar(
          existing.copyWith(
            servicoCodigo: _servicoCodigo,
            servicoNome: _servicoNome,
            empreiteiroId: _empId,
            empreiteiroNome: _empNome,
            periodo: _periodoController.text.trim(),
            ano: _ano,
            mes: _mes,
            aptos: aptos,
          ),
        );
      }
      if (!mounted) return;
      Navigator.pop(context, saved);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    final cells = _cellsDaTorre();
    final porAndar = <int, List<OperationalGridCell>>{};
    for (final c in cells) {
      porAndar.putIfAbsent(c.andar, () => []).add(c);
    }
    final andares = porAndar.keys.toList()..sort((a, b) => b.compareTo(a));
    final anoAtual = DateTime.now().year;
    final anos = {for (var a = anoAtual - 3; a <= anoAtual + 1; a++) a, _ano}.toList()
      ..sort();

    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Editar medição' : 'Nova medição')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Obra: ${_projectContext.currentProjectNameSync}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          ListTile(
            shape: RoundedRectangleBorder(
              side: BorderSide(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            leading: const Icon(Icons.handyman_outlined),
            title: Text(
              _servicoCodigo.isEmpty ? 'Escolher serviço' : '$_servicoCodigo • $_servicoNome',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickServico,
          ),
          const SizedBox(height: 10),
          ListTile(
            shape: RoundedRectangleBorder(
              side: BorderSide(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            leading: const Icon(Icons.engineering_outlined),
            title: Text(_empNome.isEmpty ? 'Escolher empreiteiro' : _empNome),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickEmpreiteiro,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _ano,
                  decoration: const InputDecoration(
                    labelText: 'Pasta: ano',
                    border: OutlineInputBorder(),
                  ),
                  items: anos
                      .map((a) => DropdownMenuItem(value: a, child: Text('$a')))
                      .toList(),
                  onChanged: (v) => setState(() => _ano = v ?? _ano),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _mes,
                  decoration: const InputDecoration(
                    labelText: 'Pasta: mês',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (var m = 1; m <= 12; m++)
                      DropdownMenuItem(value: m, child: Text(nomeMes(m))),
                  ],
                  onChanged: (v) => setState(() => _mes = v ?? _mes),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _periodoController,
            decoration: const InputDecoration(
              labelText: 'Período / nº da medição',
              hintText: 'Ex.: Medição 03 - 01 a 15/09',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Apartamentos desta medição (${_sel.length})',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in ObraStructure.torres)
                ChoiceChip(
                  label: Text(
                    _selecionadosNaTorre(t) > 0 ? '$t (${_selecionadosNaTorre(t)})' : t,
                  ),
                  selected: t == _torre,
                  onSelected: (_) => setState(() => _torre = t),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                onPressed: () => _setCells(cells, true),
                child: const Text('Selecionar todos da torre'),
              ),
              TextButton(
                onPressed: () => _setCells(cells, false),
                child: const Text('Limpar torre'),
              ),
            ],
          ),
          for (final andar in andares) ...[
            const Divider(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Andar $andar',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Builder(
                  builder: (context) {
                    final todos = porAndar[andar]!.every(
                      (c) => _sel.containsKey(_chave(c)),
                    );
                    return TextButton(
                      onPressed: () => _setCells(porAndar[andar]!, !todos),
                      child: Text(todos ? 'Nenhum do andar' : 'Todos do andar'),
                    );
                  },
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in porAndar[andar]!)
                  FilterChip(
                    label: Text(c.label),
                    selected: _sel.containsKey(_chave(c)),
                    onSelected: (_) => _toggleCell(c),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check),
            label: Text(editing ? 'Salvar alterações' : 'Criar medição'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
