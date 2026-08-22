/// Padroniza texto digitado (nome de equipamento, pessoa, material) para
/// "Primeira letra maiúscula, resto minúsculo". Usado só em texto novo
/// digitado — nunca migra registros já existentes.
String toSentenceCase(String input) {
  final trimmed = input.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (trimmed.isEmpty) return trimmed;
  final lower = trimmed.toLowerCase();
  return lower[0].toUpperCase() + lower.substring(1);
}
