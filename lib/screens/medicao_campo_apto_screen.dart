import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../models/inspection_record.dart';
import '../models/medicao_campo_record.dart';
import '../services/medicao_campo_service.dart';
import '../services/medicao_foto_service.dart';
import '../services/medicao_fvs_service.dart';
import 'inspection_screen.dart';
import '../utils/medicao_campo_rules.dart';

/// Conferência de um apartamento dentro da medição: status, observação
/// opcional e fotos (câmera ou galeria), cada uma já com a faixa de
/// identificação gravada na imagem. Salva sozinho a cada alteração.
class MedicaoCampoAptoScreen extends StatefulWidget {
  const MedicaoCampoAptoScreen({
    super.key,
    required this.medicaoId,
    required this.aptoChave,
  });

  final String medicaoId;
  final String aptoChave;

  @override
  State<MedicaoCampoAptoScreen> createState() => _MedicaoCampoAptoScreenState();
}

class _MedicaoCampoAptoScreenState extends State<MedicaoCampoAptoScreen> {
  final MedicaoCampoService _service = MedicaoCampoService.instance;
  final TextEditingController _obsController = TextEditingController();
  Timer? _obsDebounce;

  MedicaoCampoRecord? _record;
  MedicaoCampoApto? _apto;
  String _usuario = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final record = _service.buscar(widget.medicaoId);
    if (record != null) {
      _record = record;
      _apto = record.aptos.where((a) => a.chave == widget.aptoChave).firstOrNull;
      _obsController.text = _apto?.observacao ?? '';
    }
    unawaited(
      _service.resolverNomeUsuario().then((nome) {
        if (mounted) setState(() => _usuario = nome);
      }),
    );
  }

  @override
  void dispose() {
    if (_obsDebounce?.isActive == true) {
      _obsDebounce!.cancel();
      unawaited(_persistObs());
    }
    _obsController.dispose();
    super.dispose();
  }

  Future<void> _persist(MedicaoCampoApto novo) async {
    final record = _record;
    if (record == null) return;
    final atualizado = await _service.atualizarApto(record, novo);
    _record = atualizado;
    _apto = atualizado.aptos.where((a) => a.chave == novo.chave).firstOrNull;
    if (mounted) setState(() {});
  }

  Future<void> _persistObs() async {
    final apto = _apto;
    if (apto == null) return;
    final texto = _obsController.text.trim();
    if (texto == apto.observacao) return;
    await _persist(apto.copyWith(observacao: texto));
  }

  void _onObsChanged(String _) {
    _obsDebounce?.cancel();
    _obsDebounce = Timer(const Duration(milliseconds: 700), _persistObs);
  }

  Future<void> _setStatus(String status) async {
    final apto = _apto;
    if (apto == null || apto.status == status) return;
    await _persist(apto.copyWith(status: status));
  }

  Future<void> _addFoto(ImageSource source) async {
    final record = _record;
    final apto = _apto;
    if (record == null || apto == null || _busy) return;
    setState(() => _busy = true);
    try {
      if (_usuario.isEmpty) {
        _usuario = await _service.resolverNomeUsuario();
      }
      final usuario = _usuario.isNotEmpty ? _usuario : record.responsavelNome;
      final foto = await MedicaoFotoService.instance.capturar(
        source: source,
        medicao: record,
        apto: apto,
        usuario: usuario,
      );
      if (foto == null) return;
      await _persist(apto.copyWith(fotos: [...apto.fotos, foto]));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Não foi possível salvar a foto: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _abrirFvs(String elemento) async {
    final record = _record;
    final apto = _apto;
    if (record == null || apto == null) return;
    final fvs = MedicaoFvsService.instance;
    final template = fvs.templateDe(record);
    if (template == null) return;
    final existente = fvs.buscar(record, apto, elemento);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InspectionScreen(
          location: fvs.localizacao(record, apto, elemento, template),
          template: template,
          inspectionId: existente?.id,
          returnResultOnSaveFinish: true,
        ),
      ),
    );
  }

  Widget _fvsSection(MedicaoCampoRecord record, MedicaoCampoApto apto) {
    final fvs = MedicaoFvsService.instance;
    final template = fvs.templateDe(record);
    if (template == null) {
      return const Text(
        'Este serviço foi digitado à mão e não tem FVS no catálogo.',
        style: TextStyle(fontSize: 12),
      );
    }
    final elementos = fvs.elementosDaFvs(record);
    if (elementos.isEmpty) {
      return const Text(
        'Marque ao menos um elemento (Pilar, Viga, Laje...) editando a medição para gerar a FVS.',
        style: TextStyle(fontSize: 12),
      );
    }
    return ValueListenableBuilder<Box<InspectionRecord>>(
      valueListenable: Hive.box<InspectionRecord>('inspections').listenable(),
      builder: (context, box, _) {
        return Column(
          children: [
            for (final e in elementos)
              Builder(
                builder: (context) {
                  final r = fvs.buscar(record, apto, e);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(
                        r == null
                            ? Icons.assignment_outlined
                            : Icons.assignment_turned_in_outlined,
                      ),
                      title: Text(
                        'FVS ${template.codigo}${e.isEmpty ? '' : ' • $e'}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(fvs.statusLabel(r)),
                      trailing: FilledButton.tonal(
                        onPressed: () => _abrirFvs(e),
                        child: Text(r == null ? 'Preencher' : 'Abrir / editar'),
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Future<void> _removeFoto(MedicaoCampoFoto foto) async {
    final apto = _apto;
    if (apto == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir foto?'),
        content: const Text('Essa foto será removida da medição.'),
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
    await MedicaoFotoService.instance.apagarArquivo(foto);
    await _persist(
      apto.copyWith(fotos: apto.fotos.where((f) => f.id != foto.id).toList()),
    );
  }

  Future<void> _openFoto(MedicaoCampoFoto foto) async {
    final bytes = await MedicaoFotoService.instance.lerBytes(foto);
    if (!mounted) return;
    if (bytes == null && !foto.photoUrl.startsWith('http')) return;
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: InteractiveViewer(
                child: bytes != null
                    ? Image.memory(bytes)
                    : Image.network(foto.photoUrl),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(foto.legenda, style: const TextStyle(fontSize: 12)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
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
    final record = _record;
    final apto = _apto;
    if (record == null || apto == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Apartamento')),
        body: const Center(child: Text('Apartamento não encontrado na medição.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('${apto.torre} • ${rotuloLocalMedicao(apto.label)}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${record.servicoNome}\n${record.empreiteiroNome}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          const Text('Status', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              for (final s in MedicaoStatus.todos)
                ButtonSegment<String>(
                  value: s,
                  label: Text(MedicaoStatus.label(s)),
                ),
            ],
            selected: {MedicaoStatus.normalize(apto.status)},
            onSelectionChanged: (v) => _setStatus(v.first),
            style: ButtonStyle(
              foregroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? Colors.white
                    : null,
              ),
              backgroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? _statusColor(apto.status)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('FVS do local', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          _fvsSection(record, apto),
          const SizedBox(height: 8),
          TextField(
            controller: _obsController,
            maxLines: 3,
            onChanged: _onObsChanged,
            decoration: const InputDecoration(
              labelText: 'Observação (opcional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Fotos (${apto.fotos.length})',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              if (_busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : () => _addFoto(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Câmera'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _addFoto(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Galeria'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (apto.fotos.isEmpty)
            const Text('Nenhuma foto ainda.')
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: apto.fotos.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (context, i) {
                final foto = apto.fotos[i];
                return _FotoThumb(
                  foto: foto,
                  onTap: () => _openFoto(foto),
                  onDelete: () => _removeFoto(foto),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _FotoThumb extends StatelessWidget {
  const _FotoThumb({
    required this.foto,
    required this.onTap,
    required this.onDelete,
  });

  final MedicaoCampoFoto foto;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onTap,
            child: FutureBuilder<Uint8List?>(
              future: MedicaoFotoService.instance.lerBytes(foto),
              builder: (context, snap) {
                final bytes = snap.data;
                if (bytes == null && foto.photoUrl.startsWith('http')) {
                  // Sem acesso aos bytes (ex.: web sem CORS no Storage): o
                  // <img> do navegador ainda consegue mostrar a miniatura.
                  return Image.network(
                    foto.photoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) =>
                        const Icon(Icons.image_not_supported_outlined),
                  );
                }
                if (bytes == null) {
                  return Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.image_not_supported_outlined),
                  );
                }
                return Image.memory(
                  bytes,
                  fit: BoxFit.cover,
                  cacheWidth: 400,
                  gaplessPlayback: true,
                );
              },
            ),
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: InkWell(
            onTap: onDelete,
            child: const CircleAvatar(
              radius: 12,
              backgroundColor: Colors.black54,
              child: Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
