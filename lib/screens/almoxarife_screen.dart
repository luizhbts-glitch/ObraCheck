import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../services/project_context_service.dart';
import '../services/sync_orchestrator.dart';
import '../utils/project_identity.dart';
import '../utils/project_scope.dart';

class AlmoxarifeScreen extends StatefulWidget {
  const AlmoxarifeScreen({super.key});

  @override
  State<AlmoxarifeScreen> createState() => _AlmoxarifeScreenState();
}

class _AlmoxarifeScreenState extends State<AlmoxarifeScreen> {
  String _tab = 'pendentes';
  final TextEditingController _equipmentSearchCtrl = TextEditingController();
  String? _historyEquipmentId;
  DateTime? _historyStartDate;
  DateTime? _historyEndDate;
  final TextEditingController _historyNameCtrl = TextEditingController();
  final ProjectContextService _projectContext = ProjectContextService.instance;

  Box get _equipments => Hive.box('equipments');
  Box get _movements => Hive.box('equipment_movements');

  @override
  void initState() {
    super.initState();
    _ensureEquipmentCodes();
    _cleanupOldMovements();
  }

  @override
  void dispose() {
    _equipmentSearchCtrl.dispose();
    _historyNameCtrl.dispose();
    super.dispose();
  }

  String _equipmentCodeOf(Map<String, dynamic> equipment) {
    final code = (equipment['code'] ?? equipment['codigo'] ?? '').toString().trim();
    return code;
  }

  String _prefixFromName(String nome) {
    final cleaned = nome.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9\s]'), ' ');
    final parts = cleaned.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}';
    }
    if (parts.length == 1 && parts[0].isNotEmpty) {
      final first = parts[0];
      if (first.length >= 2) return first.substring(0, 2);
      return '${first}Q';
    }
    return 'EQ';
  }

  String _generateUniqueEquipmentCode(String nome, {Set<String>? reserved}) {
    final now = DateTime.now();
    final dateToken =
        '${(now.year % 100).toString().padLeft(2, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final prefix = _prefixFromName(nome);

    final used = <String>{
      for (final v in _equipments.values.whereType<Map>())
        ((v['code'] ?? v['codigo'] ?? '').toString().trim().toUpperCase()),
      ...?reserved?.map((e) => e.trim().toUpperCase()),
    }..removeWhere((e) => e.isEmpty);

    for (var seq = 1; seq <= 9999; seq++) {
      final code = '$prefix-$dateToken-${seq.toString().padLeft(3, '0')}';
      if (!used.contains(code)) return code;
    }

    return 'EQ-$dateToken-${DateTime.now().microsecondsSinceEpoch.toString().substring(10)}';
  }

  Future<void> _ensureEquipmentCodes() async {
    final currentProjectId = await ProjectContextService.instance.getCurrentProjectId();
    final updated = <Map<String, dynamic>>[];
    for (final key in _equipments.keys) {
      final raw = _equipments.get(key);
      if (raw is! Map) continue;
      final eq = Map<String, dynamic>.from(raw);
      final eqProjectId = inferProjectId(
        projectId: eq['projectId']?.toString(),
        obra: eq['obra']?.toString(),
      );
      if (eqProjectId != currentProjectId) continue;
      final current = _equipmentCodeOf(eq);
      if (current.isNotEmpty) {
        if ((eq['code'] ?? '').toString().trim().isEmpty ||
            (eq['codigo'] ?? '').toString().trim().isEmpty) {
          eq['code'] = current;
          eq['codigo'] = current;
          await _equipments.put(key, eq);
          updated.add(eq);
        }
        continue;
      }

      final generated = _generateUniqueEquipmentCode((eq['nome'] ?? '').toString());
      eq['code'] = generated;
      eq['codigo'] = generated;
      await _equipments.put(key, eq);
      updated.add(eq);
    }

    if (updated.isNotEmpty) {
      await SyncOrchestrator.instance.refreshPendingSnapshot();
    }

    if (updated.isNotEmpty && mounted) {
      setState(() {});
    }
  }

  Future<void> _cleanupOldMovements() async {
    final currentProjectId = await ProjectContextService.instance.getCurrentProjectId();
    final threshold = DateTime.now().subtract(const Duration(days: 30));
    final toTombstone = <String>[];
    for (final key in _movements.keys) {
      final v = _movements.get(key);
      if (v is Map && v['createdAt'] is DateTime) {
        final movementProjectId = inferProjectId(
          projectId: v['projectId']?.toString(),
          obra: v['obra']?.toString(),
        );
        if (movementProjectId != currentProjectId) continue;
        final dt = v['createdAt'] as DateTime;
        if (dt.isBefore(threshold) && v['deleted'] != true) {
          toTombstone.add(key.toString());
        }
      }
    }

    for (final id in toTombstone) {
      final raw = _movements.get(id);
      if (raw is! Map) continue;
      final movement = Map<String, dynamic>.from(raw);
      movement['deleted'] = true;
      movement['pendingSync'] = true;
      movement['deletedAt'] = DateTime.now();
      movement['updatedAt'] = DateTime.now();
      await _movements.put(id, movement);
    }

    if (mounted) setState(() {});
  }

  List<Map<String, dynamic>> _equipmentList() {
    final currentProjectId = _projectContext.currentProjectIdSync;
    return filterMapByProjectScope(
      _equipments.values
          .whereType<Map>()
          .where((e) => e['deleted'] != true)
          .map((e) => Map<String, dynamic>.from(e)),
      currentProjectId: currentProjectId,
    )
        .toList()
      ..sort((a, b) => (a['nome'] ?? '').toString().toLowerCase().compareTo((b['nome'] ?? '').toString().toLowerCase()));
  }

  List<Map<String, dynamic>> _movementsList() {
    final currentProjectId = _projectContext.currentProjectIdSync;
    return filterMapByProjectScope(
      _movements.values
          .whereType<Map>()
          .where((m) => m['deleted'] != true)
          .map((m) => Map<String, dynamic>.from(m)),
      currentProjectId: currentProjectId,
    )
        .toList()
      ..sort((a, b) {
        final da = a['createdAt'] as DateTime? ?? DateTime.fromMillisecondsSinceEpoch(0);
        final db = b['createdAt'] as DateTime? ?? DateTime.fromMillisecondsSinceEpoch(0);
        return db.compareTo(da);
      });
  }

  List<String> _responsibleNameSuggestions({int days = 90}) {
    final threshold = DateTime.now().subtract(Duration(days: days));
    final recent = <MapEntry<String, DateTime>>[];

    for (final raw in _movements.values) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      final name = (map['responsavel'] ?? '').toString().trim();
      if (name.isEmpty) continue;

      DateTime? createdAt;
      final value = map['createdAt'];
      if (value is DateTime) {
        createdAt = value;
      } else if (value is String) {
        createdAt = DateTime.tryParse(value);
      }

      if (createdAt == null || createdAt.isBefore(threshold)) continue;
      recent.add(MapEntry(name, createdAt));
    }

    recent.sort((a, b) => b.value.compareTo(a.value));

    final unique = <String>[];
    final seen = <String>{};
    for (final e in recent) {
      final key = e.key.toLowerCase();
      if (seen.contains(key)) continue;
      seen.add(key);
      unique.add(e.key);
    }
    return unique;
  }

  DateTime? _toDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return '-';
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} '
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateOnly(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  }

  String _historyDateRangeLabel() {
    if (_historyStartDate == null || _historyEndDate == null) return 'Sem filtro de data';
    return 'de ${_formatDateOnly(_historyStartDate!)} a ${_formatDateOnly(_historyEndDate!)}';
  }

  Future<void> _pickHistoryDateRange() async {
    final now = DateTime.now();
    final initialRange = (_historyStartDate != null && _historyEndDate != null)
        ? DateTimeRange(start: _historyStartDate!, end: _historyEndDate!)
        : DateTimeRange(start: now.subtract(const Duration(days: 6)), end: now);

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: initialRange,
      helpText: 'Selecionar intervalo',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar',
    );
    if (picked == null) return;
    setState(() {
      _historyStartDate = picked.start;
      _historyEndDate = picked.end;
    });
  }

  List<_MovementCycle> _buildMovementCycles() {
    final movements = _movementsList();
    final asc = List<Map<String, dynamic>>.from(movements)
      ..sort((a, b) {
        final da = _toDateTime(a['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final db = _toDateTime(b['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0);
        return da.compareTo(db);
      });

    final openByEquipment = <String, List<_MovementCycle>>{};
    final allCycles = <_MovementCycle>[];

    for (final movement in asc) {
      final equipmentId = (movement['equipmentId'] ?? '').toString();
      final equipmentNome = (movement['equipmentNome'] ?? '').toString();
      final responsavel = (movement['responsavel'] ?? '').toString().trim();
      final tipo = (movement['tipo'] ?? '').toString();
      final createdAt = _toDateTime(movement['createdAt']);

      if (equipmentId.isEmpty) continue;

      if (tipo == 'saida') {
        final cycle = _MovementCycle(
          equipmentId: equipmentId,
          equipmentNome: equipmentNome,
          retiradaPor: responsavel,
          devolvidoPor: '',
          saidaAt: createdAt,
          devolucaoAt: null,
        );
        allCycles.add(cycle);
        openByEquipment.putIfAbsent(equipmentId, () => <_MovementCycle>[]).add(cycle);
        continue;
      }

      if (tipo == 'devolucao') {
        final pendings = openByEquipment[equipmentId];
        if (pendings != null && pendings.isNotEmpty) {
          final cycle = pendings.removeLast();
          cycle.devolucaoAt = createdAt;
          if (responsavel.isNotEmpty) {
            cycle.devolvidoPor = responsavel;
          }
        }
      }
    }

    allCycles.sort((a, b) {
      final da = a.saidaAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final db = b.saidaAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return db.compareTo(da);
    });

    return allCycles;
  }

  List<_MovementCycle> _applyHistoryFilters(
    List<_MovementCycle> cycles,
  ) {
    final query = _historyNameCtrl.text.trim().toLowerCase();

    return cycles.where((c) {
      if (_historyEquipmentId != null && _historyEquipmentId!.isNotEmpty) {
        if (c.equipmentId != _historyEquipmentId) return false;
      }

      if (_historyStartDate != null && _historyEndDate != null) {
        final saida = c.saidaAt;
        final devolucao = c.devolucaoAt;
        final start = DateTime(_historyStartDate!.year, _historyStartDate!.month, _historyStartDate!.day);
        final end = DateTime(_historyEndDate!.year, _historyEndDate!.month, _historyEndDate!.day, 23, 59, 59, 999);
        final matchesSaida = saida != null && !saida.isBefore(start) && !saida.isAfter(end);
        final matchesDevolucao = devolucao != null && !devolucao.isBefore(start) && !devolucao.isAfter(end);
        if (!matchesSaida && !matchesDevolucao) return false;
      }

      if (query.isNotEmpty) {
        final retirada = c.retiradaPor.toLowerCase();
        final devolvido = c.devolvidoPor.toLowerCase();
        if (!retirada.contains(query) && !devolvido.contains(query)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Map<String, Map<String, dynamic>> _lastMovementByEquipment() {
    final map = <String, Map<String, dynamic>>{};
    for (final m in _movementsList()) {
      final equipmentId = (m['equipmentId'] ?? '').toString();
      if (equipmentId.isEmpty) continue;
      map.putIfAbsent(equipmentId, () => m);
    }
    return map;
  }

  String _equipmentStatusLabel(
    String equipmentId,
    Map<String, Map<String, dynamic>> lastByEquipment,
  ) {
    final movement = lastByEquipment[equipmentId];
    if (movement == null) return 'Disponível';
    return (movement['tipo'] ?? '').toString() == 'saida' ? 'Em uso' : 'Disponível';
  }

  String _equipmentCurrentResponsible(
    String equipmentId,
    Map<String, Map<String, dynamic>> lastByEquipment,
  ) {
    final movement = lastByEquipment[equipmentId];
    if (movement == null) return '-';
    if ((movement['tipo'] ?? '').toString() != 'saida') return '-';
    final name = (movement['responsavel'] ?? '').toString().trim();
    return name.isEmpty ? '-' : name;
  }

  Future<void> _showEquipmentGroupDetail(
    BuildContext context,
    String name,
    List<Map<String, dynamic>> groupItems,
    Map<String, Map<String, dynamic>> lastByEquipment,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.72,
            child: Column(
              children: [
                ListTile(
                  title: Text(
                    '$name (${groupItems.length})',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: groupItems.length,
                    separatorBuilder: (_, unusedIndex) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = groupItems[index];
                      final id = (item['id'] ?? '').toString();
                      final code = _equipmentCodeOf(item);
                      final status = _equipmentStatusLabel(id, lastByEquipment);
                      final who = _equipmentCurrentResponsible(id, lastByEquipment);
                      final movement = lastByEquipment[id];
                      final when = _toDateTime(movement?['createdAt']);
                      final isInUse = status == 'Em uso';
                      return Card(
                        color: isInUse
                            ? const Color(0xFF2A2200)
                            : theme.cardColor,
                        child: ListTile(
                          title: Text(code.isEmpty ? 'Sem código' : code),
                          subtitle: Text(
                            'Status: $status\nQuem pegou: $who\nÚltima movimentação: ${_formatDateTime(when)}',
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
  }

  bool _isUnavailableStatus(String status) {
    final normalized = status.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    return normalized == 'emprestado' ||
        normalized == 'em uso' ||
        normalized == 'com funcionário' ||
        normalized == 'com funcionario' ||
        normalized == 'indisponível' ||
        normalized == 'indisponivel';
  }

  bool _isEquipmentAvailableForCheckout(
    Map<String, dynamic> equipment,
    Map<String, Map<String, dynamic>> lastByEquipment,
  ) {
    final status = (equipment['status'] ?? '').toString();
    if (_isUnavailableStatus(status)) return false;

    final equipmentId = (equipment['id'] ?? '').toString();
    if (equipmentId.isEmpty) return false;

    final last = lastByEquipment[equipmentId];
    if (last == null) return true;
    return (last['tipo'] ?? '').toString() != 'saida';
  }

  Future<void> _deleteEquipment(Map<String, dynamic> equipment) async {
    final equipmentId = (equipment['id'] ?? '').toString();
    if (equipmentId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir equipamento'),
        content: const Text('Tem certeza que deseja excluir este equipamento?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir')),
        ],
      ),
    );

    if (confirmed != true) return;

    final tombstone = {
      ...equipment,
      'id': equipmentId,
      'projectId': _projectContext.currentProjectIdSync,
      'deleted': true,
      'pendingSync': true,
      'deletedAt': DateTime.now(),
      'updatedAt': DateTime.now(),
    };
    await _equipments.put(equipmentId, tombstone);
    if (mounted) setState(() {});
  }

  Future<void> _upsertEquipment({Map<String, dynamic>? initial}) async {
    final nomeCtrl = TextEditingController(text: (initial?['nome'] ?? '').toString());
    final qtdCtrl = TextEditingController(text: '1');

    final saved = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(dialogContext).unfocus(),
          child: AlertDialog(
            title: Text(initial == null ? 'Novo equipamento' : 'Editar equipamento'),
            content: GestureDetector(
              onTap: () {},
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nomeCtrl, decoration: const InputDecoration(labelText: 'Nome')),
                  const SizedBox(height: 8),
                  TextField(
                    controller: qtdCtrl,
                    keyboardType: TextInputType.number,
                    enabled: initial == null,
                    decoration: const InputDecoration(labelText: 'Quantidade'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () {
                  final nome = nomeCtrl.text.trim();
                  if (nome.isEmpty) return;
                  final qty = int.tryParse(qtdCtrl.text.trim()) ?? 1;
                  Navigator.pop(dialogContext, {
                    'id': (initial?['id'] ?? '').toString(),
                    'nome': nome,
                    'quantidade': qty < 1 ? 1 : qty,
                    'ativo': true,
                  });
                },
                child: const Text('Salvar'),
              ),
            ],
          ),
        );
      },
    );

    nomeCtrl.dispose();
    qtdCtrl.dispose();
    if (saved == null) return;

    final nome = (saved['nome'] ?? '').toString().trim();
    final qty = (saved['quantidade'] as int?) ?? 1;

    if (initial != null) {
      final id = (initial['id'] ?? saved['id'] ?? '').toString();
      final existing = Map<String, dynamic>.from(initial);
      final code = _equipmentCodeOf(existing).isEmpty
          ? _generateUniqueEquipmentCode(nome)
          : _equipmentCodeOf(existing);
      final equipment = {
        ...existing,
        'projectId': inferProjectId(
          projectId: existing['projectId']?.toString(),
          obra: existing['obra']?.toString(),
        ),
        'id': id,
        'nome': nome,
        'code': code,
        'codigo': code,
        'ativo': true,
        'deleted': false,
        'pendingSync': true,
        'deletedAt': null,
        'updatedAt': DateTime.now(),
      };
      await _equipments.put(id, equipment);
      await SyncOrchestrator.instance.refreshPendingSnapshot();
    } else {
      final reserved = <String>{};
      final currentProjectId = await ProjectContextService.instance.getCurrentProjectId();
      for (var i = 0; i < qty; i++) {
        final id = '${DateTime.now().microsecondsSinceEpoch}_$i';
        final code = _generateUniqueEquipmentCode(nome, reserved: reserved);
        reserved.add(code);
        final equipment = {
          'id': id,
          'projectId': currentProjectId,
          'nome': nome,
          'code': code,
          'codigo': code,
          'ativo': true,
          'deleted': false,
          'pendingSync': true,
          'deletedAt': null,
          'createdAt': DateTime.now(),
          'updatedAt': DateTime.now(),
        };
        await _equipments.put(id, equipment);
        await SyncOrchestrator.instance.refreshPendingSnapshot();
      }
    }

    if (mounted) setState(() {});
  }

  Future<void> _registrarSaida() async {
    final lastByEquipment = _lastMovementByEquipment();
    final equipments = _equipmentList()
        .where((e) => _isEquipmentAvailableForCheckout(e, lastByEquipment))
        .toList();
    final suggestions = _responsibleNameSuggestions(days: 90);
    String? equipmentId;
    String responsavel = '';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialog) => AlertDialog(
            title: const Text('Registrar saída'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: equipmentId,
                  hint: const Text('Selecione equipamento'),
                  isExpanded: true,
                  items: equipments
                      .map((e) => DropdownMenuItem<String>(
                            value: e['id'].toString(),
                            child: Text(e['nome'].toString()),
                          ))
                      .toList(),
                  onChanged: (v) => setDialog(() => equipmentId = v),
                ),
                const SizedBox(height: 8),
                Autocomplete<String>(
                  optionsMaxHeight: 180,
                  optionsBuilder: (textEditingValue) {
                    final query = textEditingValue.text.trim().toLowerCase();
                    if (query.isEmpty) {
                      return suggestions;
                    }
                    return suggestions.where((n) => n.toLowerCase().contains(query));
                  },
                  onSelected: (value) => responsavel = value,
                  fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
                    return TextField(
                      controller: textController,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        labelText: 'Nome de quem está pegando',
                      ),
                      onChanged: (value) => responsavel = value,
                    );
                  },
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Registrar')),
            ],
          ),
        );
      },
    );

    if (ok != true || equipmentId == null) {
      return;
    }

    final equipment = _equipments.get(equipmentId);
    if (equipment is! Map) {
      return;
    }

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final currentProjectId = await ProjectContextService.instance.getCurrentProjectId();
    await _movements.put(id, {
      'id': id,
      'projectId': currentProjectId,
      'equipmentId': equipmentId,
      'equipmentNome': equipment['nome'].toString(),
      'tipo': 'saida',
      'responsavel': responsavel.trim(),
      'createdAt': DateTime.now(),
      'updatedAt': DateTime.now(),
      'deleted': false,
      'pendingSync': true,
      'deletedAt': null,
    });
    final savedMovement = _movements.get(id);
    if (savedMovement is Map) {
      await SyncOrchestrator.instance.refreshPendingSnapshot();
    }
    if (mounted) setState(() {});
  }

  Future<void> _registrarDevolucao(Map<String, dynamic> pendingMovement) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar devolução'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Quem devolveu? (opcional)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmar')),
        ],
      ),
    );
    if (ok != true) {
      ctrl.dispose();
      return;
    }

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final currentProjectId = await ProjectContextService.instance.getCurrentProjectId();
    await _movements.put(id, {
      'id': id,
      'projectId': currentProjectId,
      'equipmentId': pendingMovement['equipmentId'].toString(),
      'equipmentNome': pendingMovement['equipmentNome'].toString(),
      'tipo': 'devolucao',
      'responsavel': ctrl.text.trim(),
      'createdAt': DateTime.now(),
      'updatedAt': DateTime.now(),
      'deleted': false,
      'pendingSync': true,
      'deletedAt': null,
    });
    final savedMovement = _movements.get(id);
    if (savedMovement is Map) {
      await SyncOrchestrator.instance.refreshPendingSnapshot();
    }
    ctrl.dispose();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final equipments = _equipmentList();
    final movementCycles = _buildMovementCycles();
    final lastByEquipment = _lastMovementByEquipment();
    final pendentes = lastByEquipment.values.where((m) => (m['tipo'] ?? '') == 'saida').toList();
    final equipmentGroups = <String, List<Map<String, dynamic>>>{};
    for (final equipment in equipments) {
      final key = (equipment['nome'] ?? '').toString().trim();
      equipmentGroups.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(equipment);
    }
    final equipmentGroupEntries = equipmentGroups.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
    final eqQuery = _equipmentSearchCtrl.text.trim().toLowerCase();
    final filteredEquipmentGroups = equipmentGroupEntries.where((entry) {
      if (eqQuery.isEmpty) return true;
      return entry.key.toLowerCase().contains(eqQuery);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Almoxarife • Equipamentos')),
      floatingActionButton: SafeArea(
        minimum: const EdgeInsets.only(right: 4, bottom: 4),
        child: FloatingActionButton.extended(
          onPressed: equipments.isEmpty ? null : _registrarSaida,
          icon: const Icon(Icons.outbox),
          label: const Text('Registrar saída'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(label: const Text('Pendentes'), selected: _tab == 'pendentes', onSelected: (_) => setState(() => _tab = 'pendentes')),
                ChoiceChip(label: const Text('Equipamentos'), selected: _tab == 'equipamentos', onSelected: (_) => setState(() => _tab = 'equipamentos')),
                ChoiceChip(label: const Text('Histórico (30 dias)'), selected: _tab == 'historico', onSelected: (_) => setState(() => _tab = 'historico')),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _tab == 'pendentes'
                  ? (pendentes.isEmpty
                      ? const Center(child: Text('Sem pendências de devolução.'))
                      : ListView.separated(
                          itemCount: pendentes.length,
                          separatorBuilder: (_, index) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final m = pendentes[i];
                            return Card(
                              child: ListTile(
                                title: Text(m['equipmentNome'].toString()),
                                subtitle: Text('Saída por: ${(m['responsavel'] ?? '').toString()}'),
                                trailing: Wrap(
                                  spacing: 6,
                                  children: [
                                    TextButton(
                                      onPressed: () => _registrarDevolucao(m),
                                      child: const Text('Registrar devolução'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ))
                  : _tab == 'equipamentos'
                          ? Column(
                              children: [
                                TextField(
                                  controller: _equipmentSearchCtrl,
                                  decoration: const InputDecoration(
                                    prefixIcon: Icon(Icons.search),
                                    hintText: 'Filtrar equipamento por nome',
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: FilledButton.icon(
                                    onPressed: () => _upsertEquipment(),
                                    icon: const Icon(Icons.add),
                                    label: const Text('Adicionar'),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: ListView.separated(
                                    itemCount: filteredEquipmentGroups.length,
                                    separatorBuilder: (_, index) => const SizedBox(height: 8),
                                    itemBuilder: (context, i) {
                                      final entry = filteredEquipmentGroups[i];
                                      final name = entry.key;
                                      final group = entry.value;
                                      return Card(
                                        child: ListTile(
                                          title: Text('$name (${group.length})'),
                                          subtitle: Text(
                                            group.length == 1
                                                ? 'Toque para detalhes do equipamento'
                                                : 'Toque para ver equipamentos e status',
                                          ),
                                          onTap: () async => _showEquipmentGroupDetail(
                                            context,
                                            name,
                                            group,
                                            lastByEquipment,
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                onPressed: () => _upsertEquipment(initial: group.first),
                                                icon: const Icon(Icons.edit_outlined),
                                              ),
                                              IconButton(
                                                onPressed: () async => await _deleteEquipment(group.first),
                                                icon: const Icon(Icons.delete_outline),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.black12),
                                    color: Colors.white,
                                  ),
                                  child: Column(
                                    children: [
                                      DropdownButtonFormField<String>(
                                        initialValue: _historyEquipmentId,
                                        decoration: const InputDecoration(
                                          labelText: 'Filtrar por equipamento',
                                        ),
                                        isExpanded: true,
                                        items: [
                                          const DropdownMenuItem<String>(
                                            value: null,
                                            child: Text('Todos equipamentos'),
                                          ),
                                          ...equipments.map(
                                            (e) => DropdownMenuItem<String>(
                                              value: (e['id'] ?? '').toString(),
                                              child: Text((e['nome'] ?? '').toString()),
                                            ),
                                          ),
                                        ],
                                        onChanged: (value) {
                                          setState(() {
                                            _historyEquipmentId = value;
                                          });
                                        },
                                      ),
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: _historyNameCtrl,
                                        decoration: const InputDecoration(
                                          labelText: 'Filtrar por nome (quem pegou/devolveu)',
                                        ),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: () async => await _pickHistoryDateRange(),
                                              icon: const Icon(Icons.calendar_today_outlined),
                                              label: Text(
                                                _historyDateRangeLabel(),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          TextButton(
                                            onPressed: () {
                                              setState(() {
                                                _historyEquipmentId = null;
                                                _historyStartDate = null;
                                                _historyEndDate = null;
                                                _historyNameCtrl.clear();
                                              });
                                            },
                                            child: const Text('Limpar'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: Builder(
                                    builder: (context) {
                                      final filteredCycles = _applyHistoryFilters(movementCycles);
                                      if (filteredCycles.isEmpty) {
                                        return const Center(child: Text('Sem movimentos para os filtros aplicados.'));
                                      }
                                      return ListView.separated(
                                        itemCount: filteredCycles.length,
                                        separatorBuilder: (_, index) => const SizedBox(height: 8),
                                        itemBuilder: (context, i) {
                                          final c = filteredCycles[i];
                                          final status = c.devolucaoAt == null ? 'Em uso' : 'Finalizado';
                                          final isPending = c.devolucaoAt == null;
                                          return Card(
                                            color: isPending
                                                ? const Color(0xFF2A2200)
                                                : const Color(0xFF123322),
                                            child: ListTile(
                                              title: Text(c.equipmentNome),
                                              subtitle: Text(
                                                'Responsável: ${c.retiradaPor.isEmpty ? '-' : c.retiradaPor}\n'
                                                'Devolvido por: ${c.devolvidoPor.isEmpty ? '-' : c.devolvidoPor}\n'
                                                'Saída: ${_formatDateTime(c.saidaAt)}\n'
                                                'Devolução: ${c.devolucaoAt == null ? 'Pendente' : _formatDateTime(c.devolucaoAt)}\n'
                                                'Status: $status',
                                                style: const TextStyle(color: Color(0xFFE6EDF3)),
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MovementCycle {
  _MovementCycle({
    required this.equipmentId,
    required this.equipmentNome,
    required this.retiradaPor,
    required this.devolvidoPor,
    required this.saidaAt,
    required this.devolucaoAt,
  });

  final String equipmentId;
  final String equipmentNome;
  String retiradaPor;
  String devolvidoPor;
  DateTime? saidaAt;
  DateTime? devolucaoAt;
}

