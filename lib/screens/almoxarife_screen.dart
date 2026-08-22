import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../services/project_context_service.dart';
import '../services/sync_orchestrator.dart';
import '../utils/project_identity.dart';
import '../utils/project_scope.dart';
import '../utils/similar_name.dart';
import '../utils/text_case.dart';
import 'estoque_equipamentos_screen.dart';
import 'insumos_obra_screen.dart';

class AlmoxarifeScreen extends StatefulWidget {
  const AlmoxarifeScreen({super.key});

  @override
  State<AlmoxarifeScreen> createState() => _AlmoxarifeScreenState();
}

class _AlmoxarifeScreenState extends State<AlmoxarifeScreen> {
  String _tab = 'pendentes';
  final TextEditingController _equipmentSearchCtrl = TextEditingController();
  final TextEditingController _pendingSearchCtrl = TextEditingController();
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
    _pendingSearchCtrl.dispose();
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

  /// [group] — todas as unidades cadastradas com o mesmo nome de [initial].
  /// Necessário pra saber a quantidade atual e poder ajustá-la (adicionar
  /// ou remover unidades), já que cada unidade é um registro próprio.
  Future<void> _upsertEquipment({
    Map<String, dynamic>? initial,
    List<Map<String, dynamic>>? group,
  }) async {
    final currentQty = group?.length ?? 0;
    final nomeCtrl = TextEditingController(text: (initial?['nome'] ?? '').toString());
    final qtdCtrl = TextEditingController(text: initial == null ? '1' : currentQty.toString());

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
                    decoration: InputDecoration(
                      labelText: 'Quantidade',
                      helperText: initial == null ? null : 'Atual: $currentQty',
                    ),
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

    final nome = toSentenceCase((saved['nome'] ?? '').toString());
    final qty = (saved['quantidade'] as int?) ?? 1;

    if (initial != null) {
      if (!mounted) return;
      final confirmEdit = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirmar edição'),
          content: const Text('Tem certeza que quer editar esse item?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmar')),
          ],
        ),
      );
      if (confirmEdit != true) return;

      final units = group ?? [initial];
      final diff = qty - units.length;
      var toRemove = const <Map<String, dynamic>>[];

      if (diff < 0) {
        final lastByEquipment = _lastMovementByEquipment();
        final available = units
            .where((u) => _isEquipmentAvailableForCheckout(u, lastByEquipment))
            .toList();
        if (available.length < -diff) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Não é possível reduzir para $qty: há ${units.length - available.length} '
                  'em uso e só ${available.length} disponível(is) pra remover.',
                ),
              ),
            );
          }
          return;
        }
        toRemove = available.take(-diff).toList();
      }

      final now = DateTime.now();
      for (final unit in units) {
        if (toRemove.contains(unit)) continue;
        final uid = (unit['id'] ?? '').toString();
        if (uid.isEmpty) continue;
        final code =
            _equipmentCodeOf(unit).isEmpty ? _generateUniqueEquipmentCode(nome) : _equipmentCodeOf(unit);
        final updatedUnit = {
          ...unit,
          'projectId': inferProjectId(
            projectId: unit['projectId']?.toString(),
            obra: unit['obra']?.toString(),
          ),
          'id': uid,
          'nome': nome,
          'code': code,
          'codigo': code,
          'ativo': true,
          'deleted': false,
          'pendingSync': true,
          'deletedAt': null,
          'updatedAt': now,
        };
        await _equipments.put(uid, updatedUnit);
      }

      for (final unit in toRemove) {
        final uid = (unit['id'] ?? '').toString();
        if (uid.isEmpty) continue;
        final tombstone = {
          ...unit,
          'id': uid,
          'projectId': inferProjectId(
            projectId: unit['projectId']?.toString(),
            obra: unit['obra']?.toString(),
          ),
          'deleted': true,
          'pendingSync': true,
          'deletedAt': now,
          'updatedAt': now,
        };
        await _equipments.put(uid, tombstone);
      }

      if (diff > 0) {
        final reserved = <String>{};
        final currentProjectId = await ProjectContextService.instance.getCurrentProjectId();
        for (var i = 0; i < diff; i++) {
          final id = '${DateTime.now().microsecondsSinceEpoch}_add_$i';
          final code = _generateUniqueEquipmentCode(nome, reserved: reserved);
          reserved.add(code);
          final newUnit = {
            'id': id,
            'projectId': currentProjectId,
            'nome': nome,
            'code': code,
            'codigo': code,
            'ativo': true,
            'deleted': false,
            'pendingSync': true,
            'deletedAt': null,
            'createdAt': now,
            'updatedAt': now,
          };
          await _equipments.put(id, newUnit);
        }
      }

      await SyncOrchestrator.instance.refreshPendingSnapshot();
    } else {
      final existingNames = _equipmentList()
          .map((e) => (e['nome'] ?? '').toString())
          .where((n) => n.isNotEmpty)
          .toSet();
      final similar = findSimilarNames(nome, existingNames);
      if (similar.isNotEmpty) {
        if (!mounted) return;
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Nome parecido já cadastrado'),
            content: Text(
              'Já existe equipamento com nome parecido:\n${similar.join(', ')}\n\n'
              'Quer cadastrar "$nome" mesmo assim?',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Cadastrar assim mesmo'),
              ),
            ],
          ),
        );
        if (proceed != true) return;
      }

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

  Map<String, List<Map<String, dynamic>>> _availableUnitsByName(
    Map<String, Map<String, dynamic>> lastByEquipment,
  ) {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final e in _equipmentList()) {
      if (!_isEquipmentAvailableForCheckout(e, lastByEquipment)) continue;
      final nome = (e['nome'] ?? '').toString();
      if (nome.isEmpty) continue;
      map.putIfAbsent(nome, () => <Map<String, dynamic>>[]).add(e);
    }
    return map;
  }

  Future<void> _registrarSaida() async {
    final lastByEquipment = _lastMovementByEquipment();
    final availableByName = _availableUnitsByName(lastByEquipment);
    if (availableByName.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhum equipamento disponível para saída.')),
        );
      }
      return;
    }

    final names = availableByName.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final suggestions = _responsibleNameSuggestions(days: 90);
    String responsavel = '';
    String? selectedName = names.first;
    final cart = <String, int>{};

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialog) {
            final maxAvail = selectedName == null ? 0 : availableByName[selectedName]!.length;
            final inCart = selectedName == null ? 0 : (cart[selectedName] ?? 0);
            final canAdd = selectedName != null && inCart < maxAvail;
            final canConfirm = responsavel.trim().isNotEmpty && cart.isNotEmpty;

            return AlertDialog(
              title: const Text('Registrar saída'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Autocomplete<String>(
                      optionsMaxHeight: 180,
                      optionsBuilder: (textEditingValue) {
                        final query = textEditingValue.text.trim().toLowerCase();
                        if (query.isEmpty) {
                          return suggestions;
                        }
                        return suggestions.where((n) => n.toLowerCase().contains(query));
                      },
                      onSelected: (value) => setDialog(() => responsavel = value),
                      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
                        return TextField(
                          controller: textController,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: 'Nome de quem está pegando (cartão)',
                          ),
                          onChanged: (value) => setDialog(() => responsavel = value),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Autocomplete<String>(
                            optionsMaxHeight: 220,
                            optionsBuilder: (textEditingValue) {
                              final query = textEditingValue.text.trim().toLowerCase();
                              if (query.isEmpty) return names;
                              return names.where((n) => n.toLowerCase().contains(query));
                            },
                            onSelected: (value) => setDialog(() => selectedName = value),
                            fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
                              if (textController.text.isEmpty && selectedName != null) {
                                textController.text = selectedName!;
                              }
                              return TextField(
                                controller: textController,
                                focusNode: focusNode,
                                decoration: const InputDecoration(
                                  labelText: 'Item (buscar)',
                                  prefixIcon: Icon(Icons.search),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: IconButton.filled(
                            tooltip: 'Adicionar item ao cartão',
                            onPressed: canAdd
                                ? () => setDialog(() {
                                      cart[selectedName!] = (cart[selectedName!] ?? 0) + 1;
                                    })
                                : null,
                            icon: const Icon(Icons.add),
                          ),
                        ),
                      ],
                    ),
                    if (selectedName != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Disponível: ${availableByName[selectedName]!.length - (cart[selectedName] ?? 0)}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                    const SizedBox(height: 8),
                    if (cart.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Nenhum item adicionado ainda.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    else
                      ...cart.entries.map((entry) {
                        final avail = availableByName[entry.key]!.length;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(entry.key),
                          subtitle: Text('Quantidade: ${entry.value}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () => setDialog(() {
                                  final next = entry.value - 1;
                                  if (next <= 0) {
                                    cart.remove(entry.key);
                                  } else {
                                    cart[entry.key] = next;
                                  }
                                }),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: entry.value >= avail
                                    ? null
                                    : () => setDialog(() => cart[entry.key] = entry.value + 1),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: canConfirm ? () => Navigator.pop(ctx, true) : null,
                  child: const Text('Registrar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true) return;

    final responsavelNormalizado = toSentenceCase(responsavel);
    final batchId = 'cartao_${DateTime.now().microsecondsSinceEpoch}';
    final currentProjectId = await ProjectContextService.instance.getCurrentProjectId();
    final createdAt = DateTime.now();
    var seq = 0;

    for (final entry in cart.entries) {
      final units = availableByName[entry.key] ?? const <Map<String, dynamic>>[];
      final qty = entry.value.clamp(0, units.length);
      for (var i = 0; i < qty; i++) {
        final unit = units[i];
        final unitId = (unit['id'] ?? '').toString();
        if (unitId.isEmpty) continue;
        seq++;
        final id = '${DateTime.now().microsecondsSinceEpoch}_$seq';
        await _movements.put(id, {
          'id': id,
          'projectId': currentProjectId,
          'equipmentId': unitId,
          'equipmentNome': entry.key,
          'tipo': 'saida',
          'responsavel': responsavelNormalizado,
          'batchId': batchId,
          'createdAt': createdAt,
          'updatedAt': createdAt,
          'deleted': false,
          'pendingSync': true,
          'deletedAt': null,
        });
      }
    }

    if (seq > 0) {
      await SyncOrchestrator.instance.refreshPendingSnapshot();
    }
    if (mounted) setState(() {});
  }

  Future<void> _registrarDevolucaoQty(
    List<Map<String, dynamic>> units,
    String equipmentNome,
    String responsavelSaida,
  ) async {
    final total = units.length;
    if (total == 0) return;
    int qty = total;
    final ctrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text('Devolver $equipmentNome'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Retirado por: ${responsavelSaida.isEmpty ? '-' : responsavelSaida}'),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: qty > 1 ? () => setDialog(() => qty--) : null,
                    icon: const Icon(Icons.remove),
                  ),
                  Text('$qty / $total', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    onPressed: qty < total ? () => setDialog(() => qty++) : null,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: ctrl,
                decoration: const InputDecoration(labelText: 'Quem devolveu? (opcional)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmar')),
          ],
        ),
      ),
    );

    if (ok != true) {
      ctrl.dispose();
      return;
    }

    final currentProjectId = await ProjectContextService.instance.getCurrentProjectId();
    final quemDevolveu = toSentenceCase(ctrl.text);
    final createdAt = DateTime.now();
    for (var i = 0; i < qty; i++) {
      final pendingMovement = units[i];
      final id = '${DateTime.now().microsecondsSinceEpoch}_dv_$i';
      await _movements.put(id, {
        'id': id,
        'projectId': currentProjectId,
        'equipmentId': pendingMovement['equipmentId'].toString(),
        'equipmentNome': pendingMovement['equipmentNome'].toString(),
        'tipo': 'devolucao',
        'responsavel': quemDevolveu,
        'createdAt': createdAt,
        'updatedAt': createdAt,
        'deleted': false,
        'pendingSync': true,
        'deletedAt': null,
      });
    }
    await SyncOrchestrator.instance.refreshPendingSnapshot();
    ctrl.dispose();
    if (mounted) setState(() {});
  }

  bool _sameCart(Map<String, int> a, Map<String, int> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  Future<void> _editarCartao(_PendingCard card) async {
    final lastByEquipment = _lastMovementByEquipment();
    final availableByName = _availableUnitsByName(lastByEquipment);
    final original = <String, int>{
      for (final entry in card.items.entries) entry.key: entry.value.length,
    };
    final allNames = <String>{...availableByName.keys, ...original.keys}.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    if (allNames.isEmpty) return;

    int maxFor(String name) => (original[name] ?? 0) + (availableByName[name]?.length ?? 0);

    String? selectedName = allNames.first;
    final cart = Map<String, int>.from(original);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialog) {
            final maxAvail = selectedName == null ? 0 : maxFor(selectedName!);
            final inCart = selectedName == null ? 0 : (cart[selectedName] ?? 0);
            final canAdd = selectedName != null && inCart < maxAvail;
            final changed = !_sameCart(cart, original);

            return AlertDialog(
              title: Text('Editar cartão — ${card.responsavel.isEmpty ? 'Sem responsável' : card.responsavel}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedName,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Item'),
                            items: allNames.map((n) {
                              final avail = maxFor(n) - (cart[n] ?? 0);
                              return DropdownMenuItem<String>(
                                value: n,
                                child: Text('$n (disp: $avail)'),
                              );
                            }).toList(),
                            onChanged: (v) => setDialog(() => selectedName = v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: IconButton.filled(
                            tooltip: 'Adicionar item ao cartão',
                            onPressed: canAdd
                                ? () => setDialog(() {
                                      cart[selectedName!] = (cart[selectedName!] ?? 0) + 1;
                                    })
                                : null,
                            icon: const Icon(Icons.add),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (cart.values.every((v) => v <= 0))
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Nenhum item no cartão.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    else
                      ...cart.entries.where((e) => e.value > 0).map((entry) {
                        final max = maxFor(entry.key);
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(entry.key),
                          subtitle: Text('Quantidade: ${entry.value}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () => setDialog(() {
                                  final next = entry.value - 1;
                                  if (next <= 0) {
                                    cart.remove(entry.key);
                                  } else {
                                    cart[entry.key] = next;
                                  }
                                }),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: entry.value >= max
                                    ? null
                                    : () => setDialog(() => cart[entry.key] = entry.value + 1),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: changed ? () => Navigator.pop(ctx, true) : null,
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true) return;

    final currentProjectId = await ProjectContextService.instance.getCurrentProjectId();
    final now = DateTime.now();
    var seq = 0;

    final touched = <String>{...original.keys, ...cart.keys};
    final willAddNewSaida = touched.any((n) => (cart[n] ?? 0) > (original[n] ?? 0));
    var batchId = card.key.startsWith('m_') ? '' : card.key;
    if (batchId.isEmpty && willAddNewSaida) {
      batchId = 'cartao_${now.microsecondsSinceEpoch}';
      for (final units in card.items.values) {
        for (final u in units) {
          final mid = (u['id'] ?? '').toString();
          if (mid.isEmpty) continue;
          final updated = Map<String, dynamic>.from(u)
            ..['batchId'] = batchId
            ..['pendingSync'] = true
            ..['updatedAt'] = now;
          await _movements.put(mid, updated);
        }
      }
    }

    for (final name in touched) {
      final was = original[name] ?? 0;
      final wantNow = cart[name] ?? 0;

      if (wantNow < was) {
        final units = card.items[name] ?? const <Map<String, dynamic>>[];
        final qtyReturn = (was - wantNow).clamp(0, units.length);
        for (var i = 0; i < qtyReturn; i++) {
          final pendingMovement = units[i];
          seq++;
          final id = '${now.microsecondsSinceEpoch}_edret_$seq';
          await _movements.put(id, {
            'id': id,
            'projectId': currentProjectId,
            'equipmentId': pendingMovement['equipmentId'].toString(),
            'equipmentNome': name,
            'tipo': 'devolucao',
            'responsavel': '',
            'createdAt': now,
            'updatedAt': now,
            'deleted': false,
            'pendingSync': true,
            'deletedAt': null,
          });
        }
      } else if (wantNow > was) {
        final units = availableByName[name] ?? const <Map<String, dynamic>>[];
        final qtyAdd = (wantNow - was).clamp(0, units.length);
        for (var i = 0; i < qtyAdd; i++) {
          final unit = units[i];
          final unitId = (unit['id'] ?? '').toString();
          if (unitId.isEmpty) continue;
          seq++;
          final id = '${now.microsecondsSinceEpoch}_edadd_$seq';
          await _movements.put(id, {
            'id': id,
            'projectId': currentProjectId,
            'equipmentId': unitId,
            'equipmentNome': name,
            'tipo': 'saida',
            'responsavel': card.responsavel,
            'batchId': batchId,
            'createdAt': now,
            'updatedAt': now,
            'deleted': false,
            'pendingSync': true,
            'deletedAt': null,
          });
        }
      }
    }

    if (seq > 0) {
      await SyncOrchestrator.instance.refreshPendingSnapshot();
    }
    if (mounted) setState(() {});
  }

  List<_PendingCard> _buildPendingCards(Map<String, Map<String, dynamic>> lastByEquipment) {
    final cardsByKey = <String, _PendingCard>{};
    for (final m in lastByEquipment.values) {
      if ((m['tipo'] ?? '') != 'saida') continue;
      final batchId = (m['batchId'] ?? '').toString();
      final key = batchId.isNotEmpty ? batchId : 'm_${(m['id'] ?? '').toString()}';
      final responsavel = (m['responsavel'] ?? '').toString();
      final createdAt = _toDateTime(m['createdAt']);
      final card = cardsByKey.putIfAbsent(
        key,
        () => _PendingCard(key: key, responsavel: responsavel, createdAt: createdAt),
      );
      final nome = (m['equipmentNome'] ?? '').toString();
      card.items.putIfAbsent(nome, () => <Map<String, dynamic>>[]).add(m);
    }

    final cards = cardsByKey.values.toList()
      ..sort((a, b) {
        final da = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final db = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return db.compareTo(da);
      });
    return cards;
  }

  static const List<Color> _pendingCardColors = [Color(0xFF14233A), Color(0xFF2A1F3D)];

  Widget _pendingCardWidget(_PendingCard card, Color color) {
    final itemEntries = card.items.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        color: color,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      card.responsavel.isEmpty ? 'Sem responsável' : card.responsavel,
                      style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFE6EDF3)),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Editar cartão',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    iconSize: 18,
                    icon: const Icon(Icons.edit_outlined, color: Color(0xFFE6EDF3)),
                    onPressed: () => _editarCartao(card),
                  ),
                ],
              ),
              Text(
                _formatDateTime(card.createdAt),
                style: const TextStyle(fontSize: 12, color: Color(0xFFB8C2CC)),
              ),
              const Divider(color: Colors.white24, height: 16),
              ...itemEntries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${entry.key}  x${entry.value.length}',
                          style: const TextStyle(color: Color(0xFFE6EDF3)),
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => _registrarDevolucaoQty(entry.value, entry.key, card.responsavel),
                        child: const Text('Devolver'),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingColumns(List<_PendingCard> cards) {
    final left = <_PendingCard>[];
    final right = <_PendingCard>[];
    for (var i = 0; i < cards.length; i++) {
      (i.isEven ? left : right).add(cards[i]);
    }
    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: left.map((c) => _pendingCardWidget(c, _pendingCardColors[0])).toList(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              children: right.map((c) => _pendingCardWidget(c, _pendingCardColors[1])).toList(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final equipments = _equipmentList();
    final movementCycles = _buildMovementCycles();
    final lastByEquipment = _lastMovementByEquipment();
    final pendingCards = _buildPendingCards(lastByEquipment);
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
    final pendingQuery = _pendingSearchCtrl.text.trim().toLowerCase();
    final filteredPendingCards = pendingQuery.isEmpty
        ? pendingCards
        : pendingCards.where((c) {
            if (c.responsavel.toLowerCase().contains(pendingQuery)) return true;
            return c.items.keys.any((n) => n.toLowerCase().contains(pendingQuery));
          }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Almoxarife • Equipamentos'),
        actions: [
          IconButton(
            tooltip: 'Estoque de equipamentos',
            icon: const Icon(Icons.inventory_2_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EstoqueEquipamentosScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Insumos de obra',
            icon: const Icon(Icons.warehouse_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const InsumosObraScreen()),
              );
            },
          ),
        ],
      ),
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
                  ? Column(
                      children: [
                        TextField(
                          controller: _pendingSearchCtrl,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'Buscar por pessoa ou equipamento',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: filteredPendingCards.isEmpty
                              ? Center(
                                  child: Text(
                                    pendingQuery.isEmpty
                                        ? 'Sem pendências de devolução.'
                                        : 'Nenhuma pendência encontrada para "$pendingQuery".',
                                  ),
                                )
                              : _buildPendingColumns(filteredPendingCards),
                        ),
                      ],
                    )
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
                                                onPressed: () => _upsertEquipment(
                                                  initial: group.first,
                                                  group: group,
                                                ),
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

class _PendingCard {
  _PendingCard({required this.key, required this.responsavel, required this.createdAt});

  final String key;
  final String responsavel;
  final DateTime? createdAt;
  final Map<String, List<Map<String, dynamic>>> items = {};
}

