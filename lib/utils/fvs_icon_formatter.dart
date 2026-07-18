class FvsIconFormatter {
  FvsIconFormatter._();

  static String getFvsIcon(String fvsName) {
    final normalized = _normalize(fvsName);
    if (normalized.contains('forma') || normalized.contains('carpint')) return '🪵';
    if (normalized.contains('alvenaria') || normalized.contains('bloco')) return '🧱';
    if (normalized.contains('gesso') || normalized.contains('drywall')) return '🎨';
    if (normalized.contains('piso') || normalized.contains('revestimento')) return '🧩';
    if (normalized.contains('impermeabilizacao')) return '💧';
    if (normalized.contains('hidraulica') ||
        normalized.contains('agua') ||
        normalized.contains('esgoto')) {
      return '🚿';
    }
    if (normalized.contains('eletrica')) return '⚡';
    if (normalized.contains('esquadria') || normalized.contains('janela')) return '🪟';
    if (normalized.contains('gas')) return '🔥';
    return '🏗';
  }

  static String formatFvsTitle({
    required String tower,
    required String location,
    required String contractor,
    required String fvsName,
  }) {
    final icon = getFvsIcon(fvsName);
    final t = tower.trim();
    final l = location.trim();
    final c = contractor.trim();
    final f = fvsName.trim();

    final localBase = _joinTowerAndLocation(tower: t, location: l);
    final parts = <String>[
      localBase.isNotEmpty ? localBase : 'Local não informado',
      if (c.isNotEmpty) c,
      if (f.isNotEmpty) f,
    ];
    return '$icon ${parts.join(' • ')}';
  }

  static String _joinTowerAndLocation({
    required String tower,
    required String location,
  }) {
    if (tower.isEmpty) return location;
    if (location.isEmpty) return tower;
    if (location.toLowerCase().startsWith(tower.toLowerCase())) return location;
    return '$tower $location';
  }

  static String _normalize(String raw) {
    final lower = raw.trim().toLowerCase();
    const from = 'áàâãäéèêëíìîïóòôõöúùûüç';
    const to = 'aaaaaeeeeiiiiooooouuuuc';
    final out = StringBuffer();
    for (final rune in lower.runes) {
      final ch = String.fromCharCode(rune);
      final index = from.indexOf(ch);
      if (index >= 0) {
        out.write(to[index]);
      } else {
        out.write(ch);
      }
    }
    return out.toString();
  }
}
