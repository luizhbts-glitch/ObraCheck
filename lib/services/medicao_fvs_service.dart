import 'package:hive/hive.dart';

import '../data/fvs_catalog.dart';
import '../data/fvs_location_catalog.dart';
import '../data/inspection_element_catalog.dart';
import '../models/inspection_record.dart';
import '../models/medicao_campo_record.dart';
import '../utils/medicao_campo_rules.dart';
import '../utils/report_inspection_rules.dart';

/// Liga a medição de campo às FVS (inspeções) de cada local medido. A FVS é
/// o `InspectionRecord` de sempre — mesma tela de preenchimento, mesmo
/// salvamento — só que aberta já com obra, torre, local e serviço da
/// medição. Não existe campo de vínculo: a FVS do local é encontrada pelo
/// conjunto projeto + torre + local + código da FVS + elemento.
class MedicaoFvsService {
  MedicaoFvsService._();

  static final MedicaoFvsService instance = MedicaoFvsService._();

  Box<InspectionRecord> get _box => Hive.box<InspectionRecord>('inspections');

  /// FVS do catálogo correspondente ao serviço da medição, ou `null` quando o
  /// serviço foi digitado à mão ("Outro serviço").
  FvsTemplate? templateDe(MedicaoCampoRecord medicao) {
    for (final t in FvsCatalog.all) {
      if (t.codigo == medicao.servicoCodigo) return t;
    }
    return null;
  }

  /// Formas, armadura, concretagem, fundação etc. são inspecionadas por
  /// elemento (Pilar, Viga, Laje...).
  bool exigeElemento(String servicoCodigo) =>
      InspectionElementCatalog.ruleForCode(servicoCodigo)?.requiresElement ??
      false;

  /// Elementos sugeridos pro serviço: os que a FVS aceita quando ela exige
  /// elemento, senão a lista genérica.
  List<String> elementosSugeridos(String servicoCodigo) {
    final rule = InspectionElementCatalog.ruleForCode(servicoCodigo);
    if (rule != null && rule.requiresElement) return rule.options;
    return kElementosMedicao;
  }

  /// Um item por FVS a preencher em cada local: um por elemento escolhido
  /// quando o serviço exige elemento, senão uma só (elemento vazio). Vazio
  /// quando o serviço não tem FVS no catálogo.
  List<String> elementosDaFvs(MedicaoCampoRecord medicao) {
    if (templateDe(medicao) == null) return const [];
    if (!exigeElemento(medicao.servicoCodigo)) return const [''];
    return medicao.elementos
        .where((e) => e.trim().isNotEmpty)
        .toList(growable: false);
  }

  bool _mesmoLocal(InspectionRecord r, MedicaoCampoApto apto) {
    final ref = (r.localRef ?? '').trim();
    if (ref.isNotEmpty) return ref == apto.localRef;
    return 'APTO_${r.apto}' == apto.localRef || r.apto == apto.label;
  }

  /// FVS mais recente do local para o elemento (ou `null` se ainda não foi
  /// iniciada).
  InspectionRecord? buscar(
    MedicaoCampoRecord medicao,
    MedicaoCampoApto apto,
    String elemento,
  ) {
    InspectionRecord? melhor;
    for (final r in _box.values) {
      if (r.deleted) continue;
      if (r.projectId != medicao.projectId) continue;
      if (r.torre != apto.torre) continue;
      if (r.fvsCodigo != medicao.servicoCodigo) continue;
      if (r.normalizedInspectionElement != elemento.trim()) continue;
      if (!_mesmoLocal(r, apto)) continue;
      if (melhor == null || r.updatedAt.isAfter(melhor.updatedAt)) melhor = r;
    }
    return melhor;
  }

  /// Mesmo mapa de localização que a ronda passa pra `InspectionScreen`.
  Map<String, dynamic> localizacao(
    MedicaoCampoRecord medicao,
    MedicaoCampoApto apto,
    String elemento,
    FvsTemplate template,
  ) {
    final profile = FvsLocationCatalog.profileForTemplate(template);
    return montarLocalizacao(medicao, apto, elemento, profile.defaultContextId);
  }

  /// Parte pura do mapa de localização (sem consultar configurações da obra).
  static Map<String, dynamic> montarLocalizacao(
    MedicaoCampoRecord medicao,
    MedicaoCampoApto apto,
    String elemento,
    String contexto,
  ) {
    return {
      'obra': medicao.obra,
      'projectId': medicao.projectId,
      'torre': apto.torre,
      'andar': apto.torre == kTorreGaragem ? 0 : apto.andar,
      'apto': apto.label,
      'localRef': apto.localRef,
      'localLabel': apto.label,
      'element': elemento,
      'inspectionElement': elemento,
      'locationContext': contexto,
    };
  }

  /// "Não iniciada", "Rascunho", "Finalizada", "NC aberta"...
  String statusLabel(InspectionRecord? record) =>
      record == null ? 'Não iniciada' : reportInspectionStatusLabel(record);

  /// FVS já iniciadas dos locais da medição, por `chave` do apto e depois
  /// por elemento — o que entra no PDF antes das fotos.
  Map<String, List<InspectionRecord>> fvsDaMedicao(MedicaoCampoRecord medicao) {
    final out = <String, List<InspectionRecord>>{};
    if (templateDe(medicao) == null) return out;
    for (final apto in medicao.aptos) {
      final lista = <InspectionRecord>[];
      for (final elemento in elementosDaFvs(medicao)) {
        final r = buscar(medicao, apto, elemento);
        if (r != null) lista.add(r);
      }
      if (lista.isNotEmpty) out[apto.chave] = lista;
    }
    return out;
  }

  /// Próximo local/elemento que ainda não tem FVS iniciada.
  ({MedicaoCampoApto apto, String elemento})? proximaPendente(
    MedicaoCampoRecord medicao,
  ) {
    final aptos = List<MedicaoCampoApto>.from(medicao.aptos)
      ..sort(compararAptosMedicao);
    for (final apto in aptos) {
      for (final elemento in elementosDaFvs(medicao)) {
        if (buscar(medicao, apto, elemento) == null) {
          return (apto: apto, elemento: elemento);
        }
      }
    }
    return null;
  }
}
