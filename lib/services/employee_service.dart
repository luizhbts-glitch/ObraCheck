import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/cargo_record.dart';
import '../models/employee_record.dart';
import '../models/perfil_acesso_record.dart';
import 'auth_service.dart';
import 'project_context_service.dart';

/// RH > Funcionários e Cargos — base mínima pra sustentar o resto do ERP
/// (toda tela de Compras/Despesas precisa saber "quem sou eu" como
/// funcionário, não só como usuário logado).
class EmployeeService {
  EmployeeService._();

  static final EmployeeService instance = EmployeeService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Box<EmployeeRecord> get _employees => Hive.box<EmployeeRecord>('employees');
  Box<CargoRecord> get _cargos => Hive.box<CargoRecord>('cargos');

  Future<void> _mirror(String path, Map<String, dynamic> data) async {
    try {
      await _firestore.doc(path).set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[EMPLOYEE] Falha ao espelhar $path no Firestore: $e');
    }
  }

  // ── Cargos ─────────────────────────────────────────────────────────────

  List<CargoRecord> cargos(String orgId, {bool onlyActive = true}) {
    final list = _cargos.values
        .where((c) => c.orgId == orgId && (!onlyActive || c.isActive))
        .toList()
      ..sort((a, b) => a.nivelHierarquico.compareTo(b.nivelHierarquico));
    return list;
  }

  CargoRecord? cargoById(String? id) => id == null ? null : _cargos.get(id);

  Future<CargoRecord> criarCargo({
    required String orgId,
    required String nome,
    required int nivelHierarquico,
    String? perfilAcessoIdPadrao,
  }) async {
    final now = DateTime.now();
    final record = CargoRecord(
      id: 'cargo_${now.microsecondsSinceEpoch}',
      orgId: orgId,
      nome: nome.trim(),
      nivelHierarquico: nivelHierarquico,
      perfilAcessoIdPadrao: perfilAcessoIdPadrao,
      createdAt: now,
      updatedAt: now,
    );
    await _cargos.put(record.id, record);
    await _mirror('construtoras/$orgId/cargos/${record.id}', record.toMap());
    return record;
  }

  // ── Funcionários ─────────────────────────────────────────────────────

  List<EmployeeRecord> funcionarios(
    String orgId, {
    String? projectId,
    bool onlyActive = true,
  }) {
    final list = _employees.values
        .where((e) =>
            e.orgId == orgId &&
            (!onlyActive || e.isActive) &&
            (projectId == null || e.projectId == projectId))
        .toList()
      ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
    return list;
  }

  EmployeeRecord? porId(String? id) => id == null ? null : _employees.get(id);

  /// O `EmployeeRecord` da pessoa logada, dentro da construtora informada
  /// — `null` se ela não tem cadastro de funcionário ali (ex.: só entrou
  /// como colaborador de obra sem passar por RH ainda).
  EmployeeRecord? funcionarioAtual(String orgId) {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return null;
    for (final employee in _employees.values) {
      if (employee.orgId == orgId && employee.userId == uid && employee.isActive) {
        return employee;
      }
    }
    return null;
  }

  /// Mesma coisa, resolvendo a construtora a partir da obra ativa no
  /// momento (`ProjectContextService`).
  EmployeeRecord? funcionarioAtualDaObraAtiva() {
    final orgId = ProjectContextService.instance.currentProject?.orgId ?? '';
    if (orgId.isEmpty) return null;
    return funcionarioAtual(orgId);
  }

  Future<EmployeeRecord> criarFuncionario({
    required String orgId,
    String projectId = '',
    required String cargoId,
    required String nome,
    String? avaliadorEmployeeId,
    String? userId,
  }) async {
    final now = DateTime.now();
    final record = EmployeeRecord(
      id: 'emp_${now.microsecondsSinceEpoch}',
      orgId: orgId,
      projectId: projectId,
      cargoId: cargoId,
      nome: nome.trim(),
      avaliadorEmployeeId: avaliadorEmployeeId,
      userId: userId,
      createdAt: now,
      updatedAt: now,
    );
    await _employees.put(record.id, record);
    await _mirror('construtoras/$orgId/funcionarios/${record.id}', record.toMap());
    return record;
  }

  Future<void> definirAtivo({
    required String employeeId,
    required bool isActive,
  }) async {
    final employee = _employees.get(employeeId);
    if (employee == null) return;
    final atualizado = employee.copyWith(isActive: isActive, updatedAt: DateTime.now());
    await _employees.put(atualizado.id, atualizado);
    await _mirror(
      'construtoras/${atualizado.orgId}/funcionarios/${atualizado.id}',
      atualizado.toMap(),
    );
  }

  /// Vincula a conta logada a um `EmployeeRecord` já cadastrado — usado
  /// quando alguém de RH cria o funcionário antes da pessoa ter conta, e
  /// depois a pessoa precisa "assumir" o próprio cadastro.
  Future<void> vincularContaAtual(String employeeId) async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    final employee = _employees.get(employeeId);
    if (employee == null) return;
    final atualizado = employee.copyWith(userId: uid, updatedAt: DateTime.now());
    await _employees.put(atualizado.id, atualizado);
    await _mirror(
      'construtoras/${atualizado.orgId}/funcionarios/${atualizado.id}',
      atualizado.toMap(),
    );
  }

  // ── Permissões (edição direta por pessoa) ───────────────────────────
  //
  // Decisão de 2026-08-22: em vez de obrigar todo mundo a ter um "Perfil
  // de Acesso" nomeado, a edição de permissão é direto por pessoa —
  // `permissaoOverrides` é o mecanismo principal, não um ajuste fino em
  // cima de um perfil (que continua existindo como molde opcional, mas
  // esta tela não lida com ele).

  /// Define (ou revoga) uma permissão pontual do funcionário. Sempre
  /// grava um override explícito — não existe "voltar pro perfil" aqui,
  /// já que perfil não é o mecanismo principal.
  Future<void> definirPermissao({
    required String employeeId,
    required String modulo,
    required String entidade,
    required String acao,
    required bool liberado,
    required String concedidoPorEmployeeId,
  }) async {
    final employee = _employees.get(employeeId);
    if (employee == null) return;
    final chave = '$modulo.$entidade.$acao';
    final overrides = employee.permissaoOverrides
        .where((o) => o.permissao.chave != chave)
        .toList()
      ..add(PermissaoOverride(
        permissao: PermissaoItem(modulo: modulo, entidade: entidade, acao: acao),
        liberado: liberado,
        concedidoPorEmployeeId: concedidoPorEmployeeId,
        concedidoEm: DateTime.now(),
      ));
    final atualizado = employee.copyWith(
      permissaoOverrides: overrides,
      updatedAt: DateTime.now(),
    );
    await _employees.put(atualizado.id, atualizado);
    await _mirror(
      'construtoras/${atualizado.orgId}/funcionarios/${atualizado.id}',
      atualizado.toMap(),
    );
  }

  /// Remove todos os ajustes de permissão do funcionário — volta ao
  /// estado "sem override nenhum" (efetivamente sem nenhuma permissão
  /// granular, já que não há perfil por trás disso hoje).
  Future<void> limparPermissoes(String employeeId) async {
    final employee = _employees.get(employeeId);
    if (employee == null) return;
    final atualizado = employee.copyWith(
      permissaoOverrides: const [],
      updatedAt: DateTime.now(),
    );
    await _employees.put(atualizado.id, atualizado);
    await _mirror(
      'construtoras/${atualizado.orgId}/funcionarios/${atualizado.id}',
      atualizado.toMap(),
    );
  }
}
