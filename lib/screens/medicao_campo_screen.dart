import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/company_record.dart';
import '../models/medicao_campo_record.dart';
import '../services/medicao_campo_service.dart';
import '../services/project_context_service.dart';
import '../utils/medicao_campo_rules.dart';
import 'medicao_campo_detail_screen.dart';
import 'medicao_campo_form_screen.dart';

/// Medição de campo, organizada em pastas: Ano > Mês > Empreiteiro
/// ("Eletricista - Marcio") > medições. Ano e mês podem ser criados vazios;
/// a pasta do empreiteiro nasce quando se cria a primeira medição dele.
class MedicaoCampoScreen extends StatefulWidget {
  const MedicaoCampoScreen({super.key});

  @override
  State<MedicaoCampoScreen> createState() => _MedicaoCampoScreenState();
}

class _MedicaoCampoScreenState extends State<MedicaoCampoScreen> {
  final MedicaoCampoService _service = MedicaoCampoService.instance;
  final ProjectContextService _projectContext = ProjectContextService.instance;

  int? _ano;
  int? _mes;
  String? _empKey;
  bool _sincronizando = false;

  @override
  void initState() {
    super.initState();
    unawaited(_sincronizar(manual: false));
  }

  /// Envia o que está pendente e traz as medições de outros aparelhos.
  Future<void> _sincronizar({required bool manual}) async {
    if (_sincronizando) return;
    setState(() => _sincronizando = true);
    final r = await _service.sincronizar(_projectId);
    if (!mounted) return;
    setState(() => _sincronizando = false);
    if (!manual && r.ok && r.baixadas == 0 && r.enviadas == 0) return;
    final partes = <String>[
      if (r.enviadas > 0) '${r.enviadas} enviada(s)',
      if (r.fotosEnviadas > 0) '${r.fotosEnviadas} foto(s)',
      if (r.baixadas > 0) '${r.baixadas} baixada(s)',
    ];
    final texto = r.erro != null
        ? 'Sincronização incompleta: ${r.erro}'
        : partes.isEmpty
        ? 'Tudo sincronizado.'
        : 'Sincronizado: ${partes.join(', ')}.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  String get _projectId => _projectContext.currentProjectIdSync;

  bool get _noRaiz => _ano == null;

  void _subir() {
    setState(() {
      if (_empKey != null) {
        _empKey = null;
      } else if (_mes != null) {
        _mes = null;
      } else {
        _ano = null;
      }
    });
  }

  String get _titulo {
    if (_ano == null) return 'Medição';
    if (_mes == null) return 'Medição • $_ano';
    if (_empKey == null) return '${nomeMes(_mes!)} / $_ano';
    return '${nomeMes(_mes!)} / $_ano';
  }

  Future<void> _novaPastaAno() async {
    final controller = TextEditingController(text: '${DateTime.now().year}');
    final texto = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nova pasta de ano'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Ano',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Criar'),
          ),
        ],
      ),
    );
    controller.dispose();
    final ano = int.tryParse(texto ?? '');
    if (ano == null || ano < 2000 || ano > 2100) return;
    await _service.criarPasta(_projectId, '$ano');
    if (mounted) setState(() => _ano = ano);
  }

  Future<void> _novaPastaMes() async {
    final ano = _ano;
    if (ano == null) return;
    final mes = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Nova pasta de mês'),
        children: [
          for (var m = 1; m <= 12; m++)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, m),
              child: Text(nomeMes(m)),
            ),
        ],
      ),
    );
    if (mes == null) return;
    await _service.criarPasta(_projectId, '$ano|$mes');
    if (mounted) setState(() => _mes = mes);
  }

  Future<void> _novaMedicao(List<MedicaoCampoRecord> medicoes) async {
    CompanyRecord? empresa;
    final key = _empKey;
    if (key != null) {
      final doEmp = medicoes.where((m) => chaveEmpreiteiro(m) == key).firstOrNull;
      if (doEmp != null && doEmp.empreiteiroId.isNotEmpty) {
        empresa = Hive.box<CompanyRecord>('companies').get(doEmp.empreiteiroId);
      }
    }
    final criada = await Navigator.of(context).push<MedicaoCampoRecord>(
      MaterialPageRoute(
        builder: (_) => MedicaoCampoFormScreen(
          initialAno: _ano,
          initialMes: _mes,
          initialEmpresa: empresa,
        ),
      ),
    );
    if (!mounted || criada == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MedicaoCampoDetailScreen(medicaoId: criada.id),
      ),
    );
  }

  Widget _pasta({
    required IconData icon,
    required String titulo,
    required String subtitulo,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 30),
        title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitulo),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  String _contagem(int n) => n == 1 ? '1 medição' : '$n medições';

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _noRaiz,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _subir();
      },
      child: ValueListenableBuilder<Box<MedicaoCampoRecord>>(
        valueListenable: _service.box.listenable(),
        builder: (context, box, _) {
          final medicoes = _service.listar(_projectId);
          final vazias = _service.pastasVazias(_projectId);

          final List<Widget> filhos;
          if (_ano == null) {
            final anos = anosDasPastas(medicoes, vazias);
            filhos = [
              for (final ano in anos)
                _pasta(
                  icon: Icons.folder_outlined,
                  titulo: '$ano',
                  subtitulo: _contagem(medicoes.where((m) => m.ano == ano).length),
                  onTap: () => setState(() => _ano = ano),
                ),
            ];
          } else if (_mes == null) {
            final meses = mesesDasPastas(medicoes, vazias, _ano!);
            filhos = [
              for (final mes in meses)
                _pasta(
                  icon: Icons.folder_outlined,
                  titulo: nomeMes(mes),
                  subtitulo: _contagem(
                    medicoes.where((m) => m.ano == _ano && m.mes == mes).length,
                  ),
                  onTap: () => setState(() => _mes = mes),
                ),
            ];
          } else {
            final grupos = agruparPorEmpreiteiro(medicoes, _ano!, _mes!);
            if (_empKey == null) {
              filhos = [
                for (final entry in grupos.entries)
                  _pasta(
                    icon: Icons.engineering_outlined,
                    titulo: entry.value.first.empreiteiroNome,
                    subtitulo: _contagem(entry.value.length),
                    onTap: () => setState(() => _empKey = entry.key),
                  ),
              ];
            } else {
              final lista = grupos[_empKey] ?? const <MedicaoCampoRecord>[];
              filhos = [
                for (final m in lista)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.fact_check_outlined, size: 28),
                      title: Text(
                        rotuloServico(m.servicoCodigo, m.servicoNome),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${m.periodo.trim().isEmpty ? 'Sem período' : m.periodo.trim()}'
                        '\n${m.aptos.length} apto(s) • ${m.totalFotos} foto(s)',
                      ),
                      isThreeLine: true,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MedicaoCampoDetailScreen(medicaoId: m.id),
                        ),
                      ),
                    ),
                  ),
              ];
            }
          }

          final vazio = filhos.isEmpty;
          final textoVazio = _ano == null
              ? 'Nenhuma pasta ainda. Crie a pasta do ano ou uma nova medição.'
              : _mes == null
              ? 'Nenhum mês neste ano. Crie a pasta do mês.'
              : 'Nenhuma medição aqui. Toque em "Nova medição".';

          return Scaffold(
            appBar: AppBar(
              leading: _noRaiz
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: _subir,
                    ),
              title: Text(_titulo),
              actions: [
                IconButton(
                  tooltip: _service.pendentes(_projectId) > 0
                      ? 'Sincronizar (${_service.pendentes(_projectId)} pendente(s))'
                      : 'Sincronizar',
                  onPressed: _sincronizando ? null : () => _sincronizar(manual: true),
                  icon: _sincronizando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Badge(
                          isLabelVisible: _service.pendentes(_projectId) > 0,
                          label: Text('${_service.pendentes(_projectId)}'),
                          child: const Icon(Icons.sync),
                        ),
                ),
              ],
            ),
            body: vazio
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(textoVazio, textAlign: TextAlign.center),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      if (_mes != null && _empKey != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            medicoes
                                    .where((m) => chaveEmpreiteiro(m) == _empKey)
                                    .firstOrNull
                                    ?.empreiteiroNome ??
                                '',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ...filhos,
                    ],
                  ),
            floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
            floatingActionButton: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_mes == null)
                  FloatingActionButton.extended(
                    heroTag: 'medicao_pasta',
                    onPressed: _ano == null ? _novaPastaAno : _novaPastaMes,
                    icon: const Icon(Icons.create_new_folder_outlined),
                    label: Text(_ano == null ? 'Nova pasta de ano' : 'Nova pasta de mês'),
                  ),
                if (_mes == null) const SizedBox(height: 10),
                FloatingActionButton.extended(
                  heroTag: 'medicao_nova',
                  onPressed: () => _novaMedicao(medicoes),
                  icon: const Icon(Icons.add_task),
                  label: const Text('Nova medição'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
