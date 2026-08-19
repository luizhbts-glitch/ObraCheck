/// Nível do organograma a partir do qual alguém pode aprovar despesa pra
/// pagamento — decidido em 2026-07-18: "qualquer um lança, só engenheiro
/// pra cima aprova" (nível 4 = Engenheiro/Compras/Financeiro; níveis 1-3
/// também aprovam, por serem hierarquicamente acima — número menor é
/// mais alto no organograma).
const int kNivelMinimoParaAprovarDespesa = 4;

/// Pura, sem tocar Hive/Firestore — separada do serviço só pra ser
/// testável isoladamente (mesmo espírito de `compras_status.dart`).
bool nivelPermiteAprovarDespesa(int nivelHierarquico) {
  return nivelHierarquico <= kNivelMinimoParaAprovarDespesa;
}
