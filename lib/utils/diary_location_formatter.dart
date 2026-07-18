class DiaryLocationFormatter {
  DiaryLocationFormatter._();

  static String formatLocation({
    required String localLabel,
    required String localRef,
    String? tower,
  }) {
    final normalizedTower = (tower ?? '').trim();
    var normalizedLabel = localLabel.trim();

    if (normalizedLabel.isEmpty) {
      normalizedLabel = _fallbackLabelFromRef(localRef);
    }

    if (normalizedTower.isNotEmpty) {
      final towerLower = normalizedTower.toLowerCase();
      final labelLower = normalizedLabel.toLowerCase();
      if (labelLower.startsWith(towerLower)) {
        return normalizedLabel;
      }
      if (towerLower == 'garagem') {
        if (labelLower.startsWith('garagem')) return normalizedLabel;
        return 'Garagem $normalizedLabel';
      }
      return '$normalizedTower $normalizedLabel';
    }

    if (RegExp(r'^\d+[a-zA-Z]?$').hasMatch(normalizedLabel)) {
      return 'Local $normalizedLabel';
    }

    return normalizedLabel.isNotEmpty ? normalizedLabel : 'Local não informado';
  }

  static String _fallbackLabelFromRef(String localRef) {
    final ref = localRef.trim();
    if (ref.isEmpty) return '';
    if (ref.startsWith('APTO_')) return ref.substring(5);
    switch (ref) {
      case 'ROOFTOP':
      case 'COBERTURA':
        return 'Cobertura';
      case 'HALL':
        return 'Hall';
      case 'ESCADA':
        return 'Escada';
      case 'ELEVADOR':
        return 'Elevador';
      default:
        return ref;
    }
  }
}
