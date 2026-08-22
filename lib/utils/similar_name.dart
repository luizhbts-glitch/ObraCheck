/// Distância de Levenshtein entre duas strings (nº mínimo de inserções,
/// remoções ou substituições pra transformar uma na outra).
int levenshteinDistance(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  var previousRow = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 0; i < a.length; i++) {
    final currentRow = List<int>.filled(b.length + 1, 0);
    currentRow[0] = i + 1;
    for (var j = 0; j < b.length; j++) {
      final insertCost = currentRow[j] + 1;
      final deleteCost = previousRow[j + 1] + 1;
      final substituteCost = previousRow[j] + (a[i] == b[j] ? 0 : 1);
      currentRow[j + 1] = [
        insertCost,
        deleteCost,
        substituteCost,
      ].reduce((x, y) => x < y ? x : y);
    }
    previousRow = currentRow;
  }
  return previousRow[b.length];
}

String _normalizeForComparison(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

/// Considera dois nomes "parecidos" se um contiver o outro (ex.:
/// "Lixadeira" dentro de "Lixadeira Angular") ou se a distância de edição
/// for pequena em relação ao tamanho do nome (ex.: "Lixadeira"/"Lixaderia").
/// Nomes idênticos após normalização NÃO contam como "parecidos" — esse
/// caso é o esperado (mais uma unidade do mesmo grupo), não um problema.
bool areSimilarNames(String a, String b) {
  final na = _normalizeForComparison(a);
  final nb = _normalizeForComparison(b);
  if (na.isEmpty || nb.isEmpty || na == nb) return false;
  if (na.contains(nb) || nb.contains(na)) return true;

  // Limite fixo (não proporcional ao tamanho) — nomes longos que só
  // coincidem numa terminação comum (ex.: "Lixadeira"/"Furadeira", que
  // terminam em "adeira") não devem ser marcados como parecidos.
  return levenshteinDistance(na, nb) <= 2;
}

/// Retorna, dentre `existingNames`, os que são "parecidos" com `candidate`.
List<String> findSimilarNames(String candidate, Iterable<String> existingNames) {
  return existingNames.where((n) => areSimilarNames(candidate, n)).toList();
}
