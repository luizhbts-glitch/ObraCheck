import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/inspection_record.dart';
import '../models/medicao_campo_record.dart';
import '../services/medicao_campo_service.dart';
import '../services/pdf_report_service.dart';
import '../utils/medicao_campo_rules.dart';
import '../services/medicao_fvs_service.dart';
import 'inspection_screen.dart';
import 'medicao_campo_apto_screen.dart';
import 'medicao_campo_form_screen.dart';

/// Medição aberta: dados, resumo e a lista dos apartamentos marcados. Toque
/// num apartamento pra conferir (status, observação, fotos); o botão de PDF
/// gera o comprovante só com os apartamentos desta medição.
class MedicaoCampoDetailScreen extends StatefulWidget {
  const MedicaoCampoDetailScreen({super.key, required this.medicaoId});

  final String medicaoId;

  @override
  State<MedicaoCampoDetailScreen> createState() =>
      _MedicaoCampoDetailScreenState();
}

class _MedicaoCampoDetailScreenState extends State<MedicaoCampoDetailScreen> {
  final MedicaoCampoService _service = MedicaoCampoService.instance;
  bool _generating = false;

  Future<void> _gerarPdf(MedicaoCampoRecord record) async {
    if (_generating) return;
    setState(() => _generating = true);
    try {
      final result = await PdfReportService().exportarMedicaoCampo(record);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.downloadedInBrowser
                ? 'PDF baixado: ${result.fileName}'
                : 'PDF gerado: ${result.fileName}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Falha ao gerar o PDF: $e')));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  /// Abre a FVS do próximo local que ainda não tem; ao salvar volta pra cá
  /// e o botão passa pro seguinte.
  Future<void> _preencherProxima(MedicaoCampoRecord record) async {
    final fvs = MedicaoFvsService.instance;
    final template = fvs.templateDe(record);
    final proxima = fvs.proximaPendente(record);
    if (template == null || proxima == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InspectionScreen(
          location: fvs.localizacao(record, proxima.apto, proxima.elemento, template),
          template: template,
          returnResultOnSaveFinish: true,
        ),
      ),
    );
  }

  String _fvsResumo(MedicaoCampoRecord record, MedicaoCampoApto apto) {
    final fvs = MedicaoFvsService.instance;
    final elementos = fvs.elementosDaFvs(record);
    if (elementos.isEmpty) return '';
    final feitas = elementos.where((e) => fvs.buscar(record, apto, e) != null).length;
    return ' • FVS $feitas/${elementos.length}';
  }

  Future<void> _editar(MedicaoCampoRecord record) async {
    await Navigator.of(context).push<MedicaoCampoRecord>(
      MaterialPageRoute(builder: (_) => MedicaoCampoFormScreen(existing: record)),
    );
  }

  Future<void> _excluir(MedicaoCampoRecord record) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir medição?'),
        content: Text(
          'A medição "${record.servicoNome}" com ${record.aptos.length} '
          'apartamento(s) e ${record.totalFotos} foto(s) será removida.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _service.excluir(record);
    if (mounted) Navigator.pop(context);
  }

  int _pendentes(MedicaoCampoRecord record, List<MedicaoCampoApto> aptos) {
    final fvs = MedicaoFvsService.instance;
    var n = 0;
    for (final a in aptos) {
      for (final e in fvs.elementosDaFvs(record)) {
        if (fvs.buscar(record, a, e) == null) n++;
      }
    }
    return n;
  }

  Color _statusColor(String status) {
    switch (MedicaoStatus.normalize(status)) {
      case MedicaoStatus.conferido:
        return Colors.green.shade700;
      case MedicaoStatus.problema:
        return Colors.red.shade700;
      default:
        return Colors.orange.shade800;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<InspectionRecord>>(
      valueListenable: Hive.box<InspectionRecord>('inspections').listenable(),
      builder: (context, box, child) => _buildMedicao(context),
    );
  }

  Widget _buildMedicao(BuildContext context) {
    return ValueListenableBuilder<Box<MedicaoCampoRecord>>(
      valueListenable: _service.box.listenable(keys: [widget.medicaoId]),
      builder: (context, box, _) {
        final record = box.get(widget.medicaoId);
        if (record == null || record.deleted) {
          return Scaffold(
            appBar: AppBar(title: const Text('Medição')),
            body: const Center(child: Text('Medição não encontrada.')),
          );
        }
        final aptos = List<MedicaoCampoApto>.from(record.aptos)
          ..sort(compararAptosMedicao);
        final resumo = resumirMedicao(aptos);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Medição'),
            actions: [
              IconButton(
                tooltip: 'Gerar PDF',
                onPressed: _generating ? null : () => _gerarPdf(record),
                icon: _generating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf_outlined),
              ),
              IconButton(
                tooltip: 'Editar dados e apartamentos',
                onPressed: () => _editar(record),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Excluir',
                onPressed: () => _excluir(record),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          floatingActionButton: Builder(
            builder: (context) {
              final fvs = MedicaoFvsService.instance;
              if (fvs.templateDe(record) == null) return const SizedBox.shrink();
              final elementos = fvs.elementosDaFvs(record);
              final total = elementos.length * aptos.length;
              final proxima = fvs.proximaPendente(record);
              if (total == 0) return const SizedBox.shrink();
              if (proxima == null) {
                return FloatingActionButton.extended(
                  heroTag: 'medicao_fvs_ok',
                  onPressed: null,
                  icon: const Icon(Icons.check),
                  label: const Text('Todas as FVS iniciadas'),
                );
              }
              return FloatingActionButton.extended(
                heroTag: 'medicao_fvs_proxima',
                onPressed: () => _preencherProxima(record),
                icon: const Icon(Icons.assignment_outlined),
                label: Text('Preencher FVS (${total - _pendentes(record, aptos)}/$total)'),
              );
            },
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                rotuloServico(record.servicoCodigo, record.servicoNome),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(record.empreiteiroNome),
              if (record.elementos.isNotEmpty)
                Text('Elementos: ${record.elementos.join(', ')}'),
              Text('${nomeMes(record.mes)}/${record.ano}'
                  '${record.periodo.trim().isEmpty ? '' : ' • ${record.periodo.trim()}'}'),
              Text('Responsável: ${record.responsavelNome.isEmpty ? '-' : record.responsavelNome}'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text('${resumo.totalAptos} aptos')),
                  Chip(label: Text('${resumo.conferidos} conferidos')),
                  Chip(label: Text('${resumo.pendentes} pendentes')),
                  Chip(label: Text('${resumo.comProblema} com problema')),
                  Chip(label: Text('${resumo.totalFotos} fotos')),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              for (final apto in aptos)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: _statusColor(apto.status),
                    child: const Icon(Icons.apartment, color: Colors.white, size: 18),
                  ),
                  title: Text('${rotuloLocalMedicao(apto.label)} • ${apto.torre}'),
                  subtitle: Text(
                    '${MedicaoStatus.label(apto.status)} • ${apto.fotos.length} foto(s)${_fvsResumo(record, apto)}'
                    '${apto.observacao.trim().isEmpty ? '' : '\n${apto.observacao.trim()}'}',
                  ),
                  isThreeLine: apto.observacao.trim().isNotEmpty,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MedicaoCampoAptoScreen(
                        medicaoId: record.id,
                        aptoChave: apto.chave,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
