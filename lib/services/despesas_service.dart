import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/descritivo_servico_record.dart';
import '../models/despesa_record.dart';
import '../models/medicao_empreiteiro_record.dart';
import '../models/orcamento_servico_record.dart';
import '../models/recebimento_material_record.dart';
import '../utils/despesas_rules.dart';
import 'employee_service.dart';

/// Orquestra Despesas/Financeiro: lançamento (controlada/não controlada),
/// aprovação restrita por nível do organograma, medição de empreiteiro e
/// recebimento de material com checklist de qualidade.
class DespesasService {
  DespesasService._();

  static final DespesasService instance = DespesasService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Box<DescritivoServicoRecord> get _descritivos =>
      Hive.box<DescritivoServicoRecord>('descritivos_servico');
  Box<OrcamentoServicoRecord> get _orcamentos =>
      Hive.box<OrcamentoServicoRecord>('orcamentos_servico');
  Box<MedicaoEmpreiteiroRecord> get _medicoes =>
      Hive.box<MedicaoEmpreiteiroRecord>('medicoes_empreiteiro');
  Box<RecebimentoMaterialRecord> get _recebimentos =>
      Hive.box<RecebimentoMaterialRecord>('recebimentos_material');
  Box<DespesaRecord> get _despesas => Hive.box<DespesaRecord>('despesas');

  Future<void> _mirror(String path, Map<String, dynamic> data) async {
    try {
      await _firestore.doc(path).set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[DESPESAS] Falha ao espelhar $path no Firestore: $e');
    }
  }

  String _proximoCodigo(String prefixo, Iterable<String> existentes) {
    final regex = RegExp('^${RegExp.escape(prefixo)}-(\\d+)\$');
    var maior = 0;
    for (final codigo in existentes) {
      final match = regex.firstMatch(codigo);
      if (match == null) continue;
      final numero = int.tryParse(match.group(1) ?? '') ?? 0;
      if (numero > maior) maior = numero;
    }
    return '$prefixo-${(maior + 1).toString().padLeft(4, '0')}';
  }

  /// Um funcionário pode aprovar despesa se o cargo dele está no nível 1
  /// a [kNivelMinimoParaAprovarDespesa] do organograma. Não olha
  /// `PerfilAcesso` (isso é responsabilidade de quem chama, mesma
  /// convenção do `ComprasService`) — só a regra de nível que foi
  /// decidida especificamente pra aprovação de despesa.
  bool podeAprovarDespesa(String orgId, String employeeId) {
    final employeeService = EmployeeService.instance;
    final employee = employeeService.porId(employeeId);
    if (employee == null) return false;
    final cargo = employeeService.cargoById(employee.cargoId);
    if (cargo == null) return false;
    return nivelPermiteAprovarDespesa(cargo.nivelHierarquico);
  }

  // ── Descritivo de serviço ────────────────────────────────────────────

  List<DescritivoServicoRecord> descritivosServico(String orgId, {bool onlyActive = true}) {
    final list = _descritivos.values
        .where((d) => d.orgId == orgId && (!onlyActive || d.isActive))
        .toList()
      ..sort((a, b) => a.descricao.toLowerCase().compareTo(b.descricao.toLowerCase()));
    return list;
  }

  Future<DescritivoServicoRecord> criarDescritivoServico({
    required String orgId,
    required String descricao,
    String unidadeMedida = '',
    double valorUnitarioReferencia = 0,
  }) async {
    final now = DateTime.now();
    final record = DescritivoServicoRecord(
      id: 'desc_${now.microsecondsSinceEpoch}',
      orgId: orgId,
      descricao: descricao.trim(),
      unidadeMedida: unidadeMedida.trim(),
      valorUnitarioReferencia: valorUnitarioReferencia,
      createdAt: now,
      updatedAt: now,
    );
    await _descritivos.put(record.id, record);
    await _mirror(
      'construtoras/$orgId/descritivos_servico/${record.id}',
      record.toMap(),
    );
    return record;
  }

  // ── Orçamento de serviço ──────────────────────────────────────────────

  List<OrcamentoServicoRecord> orcamentosDaObra(String projectId) {
    final list = _orcamentos.values.where((o) => o.projectId == projectId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<OrcamentoServicoRecord> criarOrcamento({
    required String projectId,
    required String empreiteiroId,
    required List<ItemOrcamento> itens,
  }) async {
    final now = DateTime.now();
    final record = OrcamentoServicoRecord(
      id: 'orc_${now.microsecondsSinceEpoch}',
      projectId: projectId,
      empreiteiroId: empreiteiroId,
      itens: itens,
      createdAt: now,
      updatedAt: now,
    );
    await _orcamentos.put(record.id, record);
    await _mirror('projects/$projectId/orcamentos_servico/${record.id}', record.toMap());
    return record;
  }

  // ── Medição de empreiteiro ────────────────────────────────────────────

  List<MedicaoEmpreiteiroRecord> medicoesDoOrcamento(String orcamentoServicoId) {
    final list = _medicoes.values
        .where((m) => m.orcamentoServicoId == orcamentoServicoId && !m.deleted)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  List<MedicaoEmpreiteiroRecord> medicoesDaObra(String projectId) {
    final list = _medicoes.values
        .where((m) => m.projectId == projectId && !m.deleted)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<MedicaoEmpreiteiroRecord> criarMedicao({
    required String orcamentoServicoId,
    required String empreiteiroId,
    required String projectId,
    String? centroCustoId,
    required String periodo,
    required List<ItemMedicao> itens,
    double adiantamentoDeduzido = 0,
    double descontoImposto = 0,
    double descontoComercial = 0,
  }) async {
    final now = DateTime.now();
    final codigo = _proximoCodigo('MED', _medicoes.values.map((m) => m.codigo));
    final record = MedicaoEmpreiteiroRecord(
      id: 'med_${now.microsecondsSinceEpoch}',
      codigo: codigo,
      orcamentoServicoId: orcamentoServicoId,
      empreiteiroId: empreiteiroId,
      projectId: projectId,
      centroCustoId: centroCustoId,
      periodo: periodo,
      itens: itens,
      adiantamentoDeduzido: adiantamentoDeduzido,
      descontoImposto: descontoImposto,
      descontoComercial: descontoComercial,
      pendingSync: true,
      createdAt: now,
      updatedAt: now,
    );
    await _medicoes.put(record.id, record);
    await _syncMedicao(record);
    return record;
  }

  Future<void> _syncMedicao(MedicaoEmpreiteiroRecord record) async {
    try {
      await _firestore
          .doc('projects/${record.projectId}/medicoes_empreiteiro/${record.id}')
          .set(record.toMap(), SetOptions(merge: true));
      await _medicoes.put(
        record.id,
        record.copyWith(pendingSync: false, updatedAt: DateTime.now()),
      );
    } catch (e) {
      debugPrint('[DESPESAS] Falha ao sincronizar medição ${record.id}: $e');
    }
  }

  Future<void> enviarMedicao(String medicaoId) async {
    final medicao = _medicoes.get(medicaoId);
    if (medicao == null) return;
    final atualizada = medicao.copyWith(
      status: StatusMedicao.enviada,
      pendingSync: true,
      updatedAt: DateTime.now(),
    );
    await _medicoes.put(atualizada.id, atualizada);
    await _syncMedicao(atualizada);
  }

  /// Aprova a medição e já gera a despesa controlada correspondente
  /// (origem `medicao_empreiteiro`, valor = líquido a pagar).
  Future<DespesaRecord> aprovarMedicao({
    required String medicaoId,
    required String aprovadoPorEmployeeId,
    String? centroCustoId,
  }) async {
    final medicao = _medicoes.get(medicaoId);
    if (medicao == null) {
      throw StateError('Medição $medicaoId não encontrada.');
    }
    final atualizada = medicao.copyWith(
      status: StatusMedicao.aprovada,
      pendingSync: true,
      updatedAt: DateTime.now(),
    );
    await _medicoes.put(atualizada.id, atualizada);
    await _syncMedicao(atualizada);

    return lancarDespesa(
      projectId: medicao.projectId,
      centroCustoId: centroCustoId ?? medicao.centroCustoId,
      tipo: TipoDespesa.controlada,
      origem: OrigemDespesa.medicaoEmpreiteiro,
      origemId: medicao.id,
      valor: medicao.valorLiquidoAPagar,
      lancadoPorEmployeeId: aprovadoPorEmployeeId,
      aprovarNaHora: true,
      aprovadoPorEmployeeId: aprovadoPorEmployeeId,
    );
  }

  // ── Recebimento de material ───────────────────────────────────────────

  List<RecebimentoMaterialRecord> recebimentosDoPedido(String pedidoCompraId) {
    final list = _recebimentos.values
        .where((r) => r.pedidoCompraId == pedidoCompraId)
        .toList()
      ..sort((a, b) => b.dataRecebimento.compareTo(a.dataRecebimento));
    return list;
  }

  /// Registra o recebimento com o checklist de qualidade e já lança a
  /// despesa controlada correspondente (origem `ordem_compra`).
  Future<RecebimentoMaterialRecord> registrarRecebimentoComQualidade({
    required String pedidoCompraId,
    required String fornecedorId,
    required String projectId,
    String? centroCustoId,
    required double valor,
    required String lancadoPorEmployeeId,
    bool prazoOk = true,
    bool condicaoOk = true,
    double? qualidadeFornecedorNota,
    List<ItemRecebimentoVerificado>? itensVerificados,
    List<String>? fotos,
  }) async {
    final now = DateTime.now();
    final recebimento = RecebimentoMaterialRecord(
      id: 'receb_${now.microsecondsSinceEpoch}',
      pedidoCompraId: pedidoCompraId,
      fornecedorId: fornecedorId,
      dataRecebimento: now,
      prazoOk: prazoOk,
      condicaoOk: condicaoOk,
      qualidadeFornecedorNota: qualidadeFornecedorNota,
      itensVerificados: itensVerificados,
      fotos: fotos,
      pendingSync: true,
      createdAt: now,
      updatedAt: now,
    );
    await _recebimentos.put(recebimento.id, recebimento);
    await _mirror(
      'projects/$projectId/recebimentos_material/${recebimento.id}',
      recebimento.toMap(),
    );

    await lancarDespesa(
      projectId: projectId,
      centroCustoId: centroCustoId,
      tipo: TipoDespesa.controlada,
      origem: OrigemDespesa.ordemCompra,
      origemId: pedidoCompraId,
      valor: valor,
      lancadoPorEmployeeId: lancadoPorEmployeeId,
    );

    return recebimento;
  }

  // ── Despesas ───────────────────────────────────────────────────────────

  List<DespesaRecord> despesas(String projectId, {String? tipo}) {
    final list = _despesas.values
        .where((d) =>
            d.projectId == projectId && !d.deleted && (tipo == null || d.tipo == tipo))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Lança uma despesa — controlada (com origem) ou não controlada
  /// (avulsa). Qualquer funcionário pode lançar; aprovação é ação
  /// separada (ver [aprovarDespesa]), a menos que `aprovarNaHora` seja
  /// passado por um fluxo que já garantiu a aprovação por outro caminho
  /// (ex.: [aprovarMedicao]).
  Future<DespesaRecord> lancarDespesa({
    required String projectId,
    String? centroCustoId,
    required String tipo,
    required String origem,
    String? origemId,
    String? descricao,
    required double valor,
    DateTime? vencimento,
    String? notaFiscalStoragePath,
    required String lancadoPorEmployeeId,
    bool aprovarNaHora = false,
    String? aprovadoPorEmployeeId,
  }) async {
    final now = DateTime.now();
    final codigo = _proximoCodigo('DESP', _despesas.values.map((d) => d.codigo));
    final record = DespesaRecord(
      id: 'desp_${now.microsecondsSinceEpoch}',
      codigo: codigo,
      projectId: projectId,
      centroCustoId: centroCustoId,
      tipo: tipo,
      origem: origem,
      origemId: origemId,
      descricao: descricao,
      valor: valor,
      vencimento: vencimento,
      notaFiscalStoragePath: notaFiscalStoragePath,
      lancadoPorEmployeeId: lancadoPorEmployeeId,
      status: aprovarNaHora ? StatusDespesa.aprovada : StatusDespesa.lancada,
      aprovadoPorEmployeeId: aprovarNaHora ? aprovadoPorEmployeeId : null,
      aprovadoEm: aprovarNaHora ? now : null,
      pendingSync: true,
      createdAt: now,
      updatedAt: now,
    );
    await _despesas.put(record.id, record);
    await _syncDespesa(record);
    return record;
  }

  Future<void> _syncDespesa(DespesaRecord record) async {
    try {
      await _firestore
          .doc('projects/${record.projectId}/despesas/${record.id}')
          .set(record.toMap(), SetOptions(merge: true));
      await _despesas.put(
        record.id,
        record.copyWith(pendingSync: false, updatedAt: DateTime.now()),
      );
    } catch (e) {
      debugPrint('[DESPESAS] Falha ao sincronizar despesa ${record.id}: $e');
    }
  }

  /// Aprova uma despesa lançada — quem chama já deve ter checado
  /// [podeAprovarDespesa] antes (mesma convenção de permissão do resto do
  /// serviço: a checagem é responsabilidade da tela, não daqui).
  Future<void> aprovarDespesa({
    required String despesaId,
    required String aprovadoPorEmployeeId,
  }) async {
    final despesa = _despesas.get(despesaId);
    if (despesa == null) return;
    final now = DateTime.now();
    final atualizada = despesa.copyWith(
      status: StatusDespesa.aprovada,
      aprovadoPorEmployeeId: aprovadoPorEmployeeId,
      aprovadoEm: now,
      pendingSync: true,
      updatedAt: now,
    );
    await _despesas.put(atualizada.id, atualizada);
    await _syncDespesa(atualizada);
  }

  Future<void> rejeitarDespesa(String despesaId) async {
    final despesa = _despesas.get(despesaId);
    if (despesa == null) return;
    final atualizada = despesa.copyWith(
      status: StatusDespesa.rejeitada,
      pendingSync: true,
      updatedAt: DateTime.now(),
    );
    await _despesas.put(atualizada.id, atualizada);
    await _syncDespesa(atualizada);
  }

  Future<void> marcarComoPaga(String despesaId) async {
    final despesa = _despesas.get(despesaId);
    if (despesa == null) return;
    final atualizada = despesa.copyWith(
      status: StatusDespesa.paga,
      pendingSync: true,
      updatedAt: DateTime.now(),
    );
    await _despesas.put(atualizada.id, atualizada);
    await _syncDespesa(atualizada);
  }
}
