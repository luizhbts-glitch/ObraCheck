import '../data/fvs_catalog.dart';
import '../data/arsen_structure.dart';
import '../models/inspection_record.dart';

class MatrixReportConfig {
  const MatrixReportConfig({
    required this.fvsCodigo,
    this.enabled = true,
  });

  final String fvsCodigo;
  final bool enabled;
}

class MatrixReportCell {
  const MatrixReportCell({
    required this.local,
    required this.status,
    required this.dataVerificacao,
    required this.responsavel,
  });

  final String local;
  final String status;
  final DateTime? dataVerificacao;
  final String responsavel;
}

class MatrixReportRow {
  const MatrixReportRow({required this.item, required this.cellsByLocal});

  final String item;
  final Map<String, MatrixReportCell> cellsByLocal;
}

class MatrixReportData {
  const MatrixReportData({
    required this.obra,
    required this.torre,
    required this.fvsCodigo,
    required this.fvsNome,
    required this.locais,
    required this.itens,
    required this.rows,
    required this.generatedAt,
  });

  final String obra;
  final String torre;
  final String fvsCodigo;
  final String fvsNome;
  final List<String> locais;
  final List<String> itens;
  final List<MatrixReportRow> rows;
  final DateTime generatedAt;
}

class MatrixReportBuilder {
  static bool supportsFvs(String fvsCodigo) {
    final code = fvsCodigo.trim();
    return code.isNotEmpty;
  }

  static MatrixReportData build({
    required String obra,
    required String torre,
    required String fvsCodigo,
    required String fvsNome,
    required List<InspectionRecord> source,
    required String responsavel,
  }) {
    final latestByLocal = <String, InspectionRecord>{};

    for (final record in source) {
      if (record.obra != obra) continue;
      if (record.torre != torre) continue;
      if (record.fvsCodigo != fvsCodigo) continue;

      final localRef = _recordLocalRef(record);
      final current = latestByLocal[localRef];
      if (current == null || record.updatedAt.isAfter(current.updatedAt)) {
        latestByLocal[localRef] = record;
      }
    }

    final locais = _buildLocais(torre: torre, recordsByLocal: latestByLocal);
    final itens = _buildItens(
      records: latestByLocal.values.toList(),
      fvsCodigo: fvsCodigo,
    );

    final rows = <MatrixReportRow>[];
    for (int index = 0; index < itens.length; index++) {
      final item = itens[index];
      final cellsByLocal = <String, MatrixReportCell>{};

      for (final local in locais) {
        final localRef = _localLabelToRef(label: local, torre: torre);
        final rec = latestByLocal[localRef];
        final itemResult = rec != null && rec.itens.length > index ? rec.itens[index] : null;

        cellsByLocal[local] = MatrixReportCell(
          local: local,
          status: itemResult?.status ?? 'none',
          dataVerificacao: rec?.updatedAt,
          responsavel: responsavel,
        );
      }

      rows.add(MatrixReportRow(item: item, cellsByLocal: cellsByLocal));
    }

    return MatrixReportData(
      obra: obra,
      torre: torre,
      fvsCodigo: fvsCodigo,
      fvsNome: fvsNome,
      locais: locais,
      itens: itens,
      rows: rows,
      generatedAt: DateTime.now(),
    );
  }

  static List<String> _buildLocais({
    required String torre,
    required Map<String, InspectionRecord> recordsByLocal,
  }) {
    final out = <String>[];

    final maxFloor = _maxResidentialFloor();
    for (int floor = 1; floor <= maxFloor; floor++) {
      out.addAll(ObraStructure.apartamentosDoAndar(floor));
    }

    final specials = ObraStructure.specialAreasForTower(torre).map((e) => e.label).toList(growable: false);
    out.addAll(specials);

    final extra = recordsByLocal.keys
        .map(_localRefToLabel)
        .where((label) => !out.contains(label))
        .toList()
      ..sort((a, b) => _compareLocationNumeric(a, b));
    out.addAll(extra);

    return out;
  }

  static int _compareLocationNumeric(String a, String b) {
    final aNumber = _extractLocationOrderNumber(a);
    final bNumber = _extractLocationOrderNumber(b);
    if (aNumber != null && bNumber != null) {
      final byNumber = aNumber.compareTo(bNumber);
      if (byNumber != 0) return byNumber;
      return a.toLowerCase().compareTo(b.toLowerCase());
    }
    if (aNumber != null) return -1;
    if (bNumber != null) return 1;
    return a.toLowerCase().compareTo(b.toLowerCase());
  }

  static int? _extractLocationOrderNumber(String location) {
    final trimmed = location.trim();
    if (trimmed.isEmpty) return null;
    final direct = int.tryParse(trimmed);
    if (direct != null) return direct;
    final match = RegExp(r'\d+').firstMatch(trimmed);
    if (match == null) return null;
    return int.tryParse(match.group(0) ?? '');
  }

  static List<String> _buildItens({
    required List<InspectionRecord> records,
    required String fvsCodigo,
  }) {
    for (final t in FvsCatalog.all) {
      if (t.codigo.trim() == fvsCodigo.trim()) {
        return t.itens.map((e) => e.descricao).toList();
      }
    }

    if (records.isEmpty) return const <String>[];
    records.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return records.first.itens.map((e) => e.descricao).toList();
  }

  static String _recordLocalRef(InspectionRecord r) {
    final ref = r.localRef?.trim();
    if (ref != null && ref.isNotEmpty) return ref;
    return 'APTO_${r.apto}';
  }

  static String _localRefToLabel(String ref) {
    if (ref.startsWith('APTO_')) {
      final after = ref.substring(5);
      if (RegExp(r'^\d+$').hasMatch(after)) return after;
      if (after.contains('_')) {
        final parts = after.split('_');
        if (parts.length == 2) {
          final floor = parts[0];
          final unit = parts[1];
          final unitNum = int.tryParse(unit);
          if (unitNum != null) {
            final unitSuffix = unitNum.toString().padLeft(2, '0');
            return '$floor$unitSuffix';
          }
        }
      }
      return after.replaceAll('_', ' ');
    }
    if (ref.startsWith('STRUCT_')) return ref.substring(7).replaceAll('_', ' ');
    if (ref.startsWith('FACADE_')) return ref.substring(7).replaceAll('_', ' ');
    if (ref.startsWith('SECTOR_')) return ref.substring(7).replaceAll('_', ' ');
    if (ref.startsWith('FREE_')) return ref.substring(5).replaceAll('_', ' ');
    if (ref == 'ROOFTOP' || ref == 'COBERTURA') return 'Rooftop';
    return ref;
  }

  static String _localLabelToRef({required String label, required String torre}) {
    if (RegExp(r'^\d{3,4}$').hasMatch(label)) return 'APTO_$label';
    if (label == 'Rooftop') return 'ROOFTOP';
    for (final area in ObraStructure.specialAreasForTower(torre)) {
      if (area.label == label) return area.localRef;
    }
    return label.toUpperCase().replaceAll(' ', '_');
  }

  static int _maxResidentialFloor() {
    final labels = ObraStructure.andares();
    var max = 16;
    for (final label in labels) {
      final digits = label.replaceAll(RegExp(r'[^0-9]'), '');
      final parsed = int.tryParse(digits);
      if (parsed != null && parsed > max) {
        max = parsed;
      }
    }
    return max;
  }
}
