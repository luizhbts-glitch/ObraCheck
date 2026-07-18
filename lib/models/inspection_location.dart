class InspectionLocation {
  const InspectionLocation({
    required this.type,
    required this.tower,
    this.floor,
    this.unit,
    this.element,
    this.sector,
  });

  final String type;
  final String tower;
  final String? floor;
  final String? unit;
  final String? element;
  final String? sector;

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'tower': tower,
      'floor': floor,
      'unit': unit,
      'element': element,
      'sector': sector,
    };
  }

  factory InspectionLocation.fromMap(Map<String, dynamic> map) {
    return InspectionLocation(
      type: (map['type'] ?? '').toString().trim(),
      tower: (map['tower'] ?? '').toString().trim(),
      floor: map['floor']?.toString().trim(),
      unit: map['unit']?.toString().trim(),
      element: map['element']?.toString().trim(),
      sector: map['sector']?.toString().trim(),
    );
  }

  factory InspectionLocation.fromLegacyMap(Map<String, dynamic> map) {
    final type = _resolveType(map);
    final tower = (map['torre'] ?? map['tower'] ?? '').toString().trim();
    final floorRaw = map['andar'];
    final floor = floorRaw?.toString().trim();
    final unit = (map['localLabel'] ?? map['apto'] ?? map['unit'] ?? '').toString().trim();
    final element = (map['inspectionElement'] ?? map['element'] ?? '').toString().trim();
    final sector = (map['sector'] ?? map['modulo'] ?? map['localRef'] ?? '').toString().trim();

    return InspectionLocation(
      type: type,
      tower: tower,
      floor: floor?.isEmpty ?? true ? null : floor,
      unit: unit.isEmpty ? null : unit,
      element: element.isEmpty ? null : element,
      sector: sector.isEmpty ? null : sector,
    );
  }

  static String _resolveType(Map<String, dynamic> map) {
    final explicit = (map['locationType'] ?? map['type'] ?? '').toString().trim();
    if (explicit.isNotEmpty) return explicit;

    final localRef = (map['localRef'] ?? '').toString().trim().toUpperCase();
    if (localRef.startsWith('STRUCT_')) return 'structural';
    if (localRef.startsWith('SECTOR_')) return 'sector';
    if (localRef.startsWith('FACADE_')) return 'facade';
    if (localRef.startsWith('FREE_')) return 'free';
    return 'unit';
  }
}
