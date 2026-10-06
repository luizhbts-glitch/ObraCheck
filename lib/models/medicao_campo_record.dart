import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'medicao_campo_record.g.dart';

/// Medição de campo: conferência de um serviço por apartamento, com fotos
/// identificadas, que vira um PDF de comprovação do que está sendo pago.
/// Não tem relação com `MedicaoEmpreiteiroRecord` (medição financeira
/// mensal do empreiteiro, usada em Despesas) — por isso o sufixo "Campo".
class MedicaoStatus {
  static const String conferido = 'conferido';
  static const String pendente = 'pendente';
  static const String problema = 'problema';

  static const List<String> todos = [conferido, pendente, problema];

  static String label(String status) {
    switch (status) {
      case conferido:
        return 'Conferido';
      case problema:
        return 'Com problema';
      default:
        return 'Pendente';
    }
  }

  static String normalize(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    return todos.contains(value) ? value : pendente;
  }
}

DateTime _medicaoToDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
  }
  return DateTime.now();
}

@HiveType(typeId: 42)
class MedicaoCampoFoto {
  @HiveField(0)
  final String id;

  /// Caminho do arquivo no aparelho (mobile).
  @HiveField(1)
  final String localPath;

  /// Foto em data URL (web, onde não existe arquivo local).
  @HiveField(2)
  final String dataUrl;

  /// URL remota depois de subir pro Storage.
  @HiveField(3)
  final String photoUrl;

  @HiveField(4)
  final String storagePath;

  /// Texto de identificação (já gravado na própria imagem e impresso no PDF).
  @HiveField(5)
  final String legenda;

  @HiveField(6)
  final DateTime capturedAt;

  @HiveField(7)
  final String usuario;

  @HiveField(8)
  final bool pendingSync;

  const MedicaoCampoFoto({
    required this.id,
    this.localPath = '',
    this.dataUrl = '',
    this.photoUrl = '',
    this.storagePath = '',
    this.legenda = '',
    required this.capturedAt,
    this.usuario = '',
    this.pendingSync = true,
  });

  MedicaoCampoFoto copyWith({
    String? localPath,
    String? dataUrl,
    String? photoUrl,
    String? storagePath,
    String? legenda,
    bool? pendingSync,
  }) {
    return MedicaoCampoFoto(
      id: id,
      localPath: localPath ?? this.localPath,
      dataUrl: dataUrl ?? this.dataUrl,
      photoUrl: photoUrl ?? this.photoUrl,
      storagePath: storagePath ?? this.storagePath,
      legenda: legenda ?? this.legenda,
      capturedAt: capturedAt,
      usuario: usuario,
      pendingSync: pendingSync ?? this.pendingSync,
    );
  }

  /// Sem `dataUrl`/`localPath`: o espelho no Firestore guarda só metadados,
  /// a imagem em si vai pro Storage.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'photoUrl': photoUrl,
      'storagePath': storagePath,
      'legenda': legenda,
      'capturedAt': Timestamp.fromDate(capturedAt),
      'usuario': usuario,
    };
  }

  factory MedicaoCampoFoto.fromMap(Map<String, dynamic> map) {
    return MedicaoCampoFoto(
      id: (map['id'] ?? '').toString(),
      photoUrl: (map['photoUrl'] ?? '').toString(),
      storagePath: (map['storagePath'] ?? '').toString(),
      legenda: (map['legenda'] ?? '').toString(),
      capturedAt: _medicaoToDate(map['capturedAt']),
      usuario: (map['usuario'] ?? '').toString(),
      pendingSync: false,
    );
  }
}

@HiveType(typeId: 41)
class MedicaoCampoApto {
  @HiveField(0)
  final String torre;

  /// Ex.: `APTO_1101`.
  @HiveField(1)
  final String localRef;

  /// Ex.: `1101`.
  @HiveField(2)
  final String label;

  @HiveField(3)
  final int andar;

  @HiveField(4)
  final String status;

  @HiveField(5)
  final String observacao;

  @HiveField(6)
  final List<MedicaoCampoFoto> fotos;

  const MedicaoCampoApto({
    required this.torre,
    required this.localRef,
    required this.label,
    required this.andar,
    this.status = MedicaoStatus.pendente,
    this.observacao = '',
    this.fotos = const [],
  });

  String get chave => '$torre|$localRef';

  MedicaoCampoApto copyWith({
    String? status,
    String? observacao,
    List<MedicaoCampoFoto>? fotos,
  }) {
    return MedicaoCampoApto(
      torre: torre,
      localRef: localRef,
      label: label,
      andar: andar,
      status: status ?? this.status,
      observacao: observacao ?? this.observacao,
      fotos: fotos ?? this.fotos,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'torre': torre,
      'localRef': localRef,
      'label': label,
      'andar': andar,
      'status': status,
      'observacao': observacao,
      'fotos': fotos.map((f) => f.toMap()).toList(),
    };
  }

  factory MedicaoCampoApto.fromMap(Map<String, dynamic> map) {
    final rawFotos = (map['fotos'] as List?) ?? const [];
    return MedicaoCampoApto(
      torre: (map['torre'] ?? '').toString(),
      localRef: (map['localRef'] ?? '').toString(),
      label: (map['label'] ?? '').toString(),
      andar: (map['andar'] as num?)?.toInt() ?? 0,
      status: MedicaoStatus.normalize(map['status']?.toString()),
      observacao: (map['observacao'] ?? '').toString(),
      fotos: rawFotos
          .whereType<Map>()
          .map((e) => MedicaoCampoFoto.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

@HiveType(typeId: 40)
class MedicaoCampoRecord extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String projectId;

  @HiveField(2)
  final String obra;

  @HiveField(3)
  final String servicoCodigo;

  @HiveField(4)
  final String servicoNome;

  @HiveField(5)
  final String empreiteiroId;

  @HiveField(6)
  final String empreiteiroNome;

  /// Período ou número da medição, texto livre (ex.: "Medição 03 - set/26").
  @HiveField(7)
  final String periodo;

  /// Nome de quem criou — gravado na criação pra funcionar offline (o perfil
  /// do usuário vem do Firestore).
  @HiveField(8)
  final String responsavelNome;

  @HiveField(9)
  final List<MedicaoCampoApto> aptos;

  @HiveField(10)
  final bool deleted;

  @HiveField(11)
  final bool pendingSync;

  @HiveField(12)
  final DateTime createdAt;

  @HiveField(13)
  final DateTime updatedAt;

  /// Pasta "ano" (ex.: 2026) onde a medição fica organizada.
  @HiveField(14)
  final int ano;

  /// Pasta "mês" (1-12) dentro do ano.
  @HiveField(15)
  final int mes;

  /// Elementos medidos (Laje, Viga, Pilar...) — opcional, usado em serviços
  /// estruturais como carpintaria, concretagem e alvenaria.
  @HiveField(16, defaultValue: <String>[])
  final List<String> elementos;

  MedicaoCampoRecord({
    required this.id,
    required this.projectId,
    required this.obra,
    required this.servicoCodigo,
    required this.servicoNome,
    this.empreiteiroId = '',
    this.empreiteiroNome = '',
    this.periodo = '',
    this.responsavelNome = '',
    this.aptos = const [],
    this.deleted = false,
    this.pendingSync = false,
    required this.createdAt,
    required this.updatedAt,
    required this.ano,
    required this.mes,
    this.elementos = const [],
  });

  int get totalFotos => aptos.fold<int>(0, (total, a) => total + a.fotos.length);

  MedicaoCampoRecord copyWith({
    String? servicoCodigo,
    String? servicoNome,
    String? empreiteiroId,
    String? empreiteiroNome,
    String? periodo,
    String? responsavelNome,
    List<MedicaoCampoApto>? aptos,
    bool? deleted,
    bool? pendingSync,
    DateTime? updatedAt,
    int? ano,
    int? mes,
    List<String>? elementos,
  }) {
    return MedicaoCampoRecord(
      id: id,
      projectId: projectId,
      obra: obra,
      servicoCodigo: servicoCodigo ?? this.servicoCodigo,
      servicoNome: servicoNome ?? this.servicoNome,
      empreiteiroId: empreiteiroId ?? this.empreiteiroId,
      empreiteiroNome: empreiteiroNome ?? this.empreiteiroNome,
      periodo: periodo ?? this.periodo,
      responsavelNome: responsavelNome ?? this.responsavelNome,
      aptos: aptos ?? this.aptos,
      deleted: deleted ?? this.deleted,
      pendingSync: pendingSync ?? this.pendingSync,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      ano: ano ?? this.ano,
      mes: mes ?? this.mes,
      elementos: elementos ?? this.elementos,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'projectId': projectId,
      'obra': obra,
      'ano': ano,
      'mes': mes,
      'elementos': elementos,
      'servicoCodigo': servicoCodigo,
      'servicoNome': servicoNome,
      'empreiteiroId': empreiteiroId,
      'empreiteiroNome': empreiteiroNome,
      'periodo': periodo,
      'responsavelNome': responsavelNome,
      'aptos': aptos.map((a) => a.toMap()).toList(),
      'deleted': deleted,
      'pendingSync': pendingSync,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory MedicaoCampoRecord.fromMap(Map<String, dynamic> map) {
    final rawAptos = (map['aptos'] as List?) ?? const [];
    return MedicaoCampoRecord(
      id: (map['id'] ?? '').toString(),
      projectId: (map['projectId'] ?? '').toString(),
      obra: (map['obra'] ?? '').toString(),
      servicoCodigo: (map['servicoCodigo'] ?? '').toString(),
      servicoNome: (map['servicoNome'] ?? '').toString(),
      empreiteiroId: (map['empreiteiroId'] ?? '').toString(),
      empreiteiroNome: (map['empreiteiroNome'] ?? '').toString(),
      periodo: (map['periodo'] ?? '').toString(),
      responsavelNome: (map['responsavelNome'] ?? '').toString(),
      aptos: rawAptos
          .whereType<Map>()
          .map((e) => MedicaoCampoApto.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      deleted: map['deleted'] == true,
      pendingSync: map['pendingSync'] == true,
      createdAt: _medicaoToDate(map['createdAt']),
      updatedAt: _medicaoToDate(map['updatedAt']),
      elementos: ((map['elementos'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      ano: (map['ano'] as num?)?.toInt() ?? _medicaoToDate(map['createdAt']).year,
      mes: (map['mes'] as num?)?.toInt() ?? _medicaoToDate(map['createdAt']).month,
    );
  }
}
