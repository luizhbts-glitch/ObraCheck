import '../models/medicao_campo_record.dart';

/// Linhas de identificação gravadas na faixa da foto e impressas no PDF:
/// obra, torre, apartamento, serviço, empreiteiro, data/hora e usuário.
/// Função pura — sem dependência de plugin — pra poder ser testada.
List<String> buildMedicaoFotoLegendaLinhas({
  required String obra,
  required String torre,
  required String apto,
  required String servico,
  required String empreiteiro,
  required DateTime dataHora,
  required String usuario,
}) {
  String orDash(String v) => v.trim().isEmpty ? '-' : v.trim();
  return [
    'Obra: ${orDash(obra)} | Torre: ${orDash(torre)} | ${rotuloLocalMedicao(apto)}',
    'Serviço: ${orDash(servico)} | Empreiteiro: ${orDash(empreiteiro)}',
    '${formatMedicaoDataHora(dataHora)} | Usuário: ${orDash(usuario)}',
  ];
}

/// "Apto 1101" para apartamento; área comum (Rooftop, Barrilete, Caixa
/// d'água...) usa só o nome.
String rotuloLocalMedicao(String label) {
  final l = label.trim();
  if (l.isEmpty) return 'Local: -';
  return RegExp(r'^\d+$').hasMatch(l) ? 'Apto $l' : l;
}

String buildMedicaoFotoLegenda({
  required String obra,
  required String torre,
  required String apto,
  required String servico,
  required String empreiteiro,
  required DateTime dataHora,
  required String usuario,
}) {
  return buildMedicaoFotoLegendaLinhas(
    obra: obra,
    torre: torre,
    apto: apto,
    servico: servico,
    empreiteiro: empreiteiro,
    dataHora: dataHora,
    usuario: usuario,
  ).join('\n');
}

String formatMedicaoDataHora(DateTime dt) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
}

class MedicaoResumo {
  const MedicaoResumo({
    required this.totalAptos,
    required this.conferidos,
    required this.pendentes,
    required this.comProblema,
    required this.totalFotos,
  });

  final int totalAptos;
  final int conferidos;
  final int pendentes;
  final int comProblema;
  final int totalFotos;
}

MedicaoResumo resumirMedicao(List<MedicaoCampoApto> aptos) {
  var conferidos = 0;
  var pendentes = 0;
  var problema = 0;
  var fotos = 0;
  for (final a in aptos) {
    fotos += a.fotos.length;
    switch (MedicaoStatus.normalize(a.status)) {
      case MedicaoStatus.conferido:
        conferidos++;
        break;
      case MedicaoStatus.problema:
        problema++;
        break;
      default:
        pendentes++;
    }
  }
  return MedicaoResumo(
    totalAptos: aptos.length,
    conferidos: conferidos,
    pendentes: pendentes,
    comProblema: problema,
    totalFotos: fotos,
  );
}

/// Retorna a mensagem de erro, ou `null` se a nova medição é válida.
String? validarNovaMedicao({
  required String servicoCodigo,
  required String empreiteiroNome,
  required int totalAptosSelecionados,
  bool exigeElemento = false,
  int totalElementos = 0,
}) {
  if (servicoCodigo.trim().isEmpty) return 'Escolha o serviço.';
  if (empreiteiroNome.trim().isEmpty) return 'Escolha o empreiteiro.';
  if (exigeElemento && totalElementos < 1) {
    return 'Este serviço é inspecionado por elemento: marque ao menos um (Pilar, Viga, Laje...).';
  }
  if (totalAptosSelecionados < 1) {
    return 'Marque ao menos um apartamento ou área comum.';
  }
  return null;
}

/// Ordena aptos por torre e depois numericamente (1101 antes de 1102, 2101...).
int compararAptosMedicao(MedicaoCampoApto a, MedicaoCampoApto b) {
  final byTorre = a.torre.compareTo(b.torre);
  if (byTorre != 0) return byTorre;
  final an = int.tryParse(a.label);
  final bn = int.tryParse(b.label);
  if (an != null && bn != null) return an.compareTo(bn);
  if (an != null) return -1;
  if (bn != null) return 1;
  // Áreas comuns e estacionamento: pela ordem lógica (andar guarda o rank,
  // ex.: módulo 1 subsolo antes de módulo 1 térreo) e depois pelo nome.
  final byAndar = a.andar.compareTo(b.andar);
  if (byAndar != 0) return byAndar;
  return a.label.compareTo(b.label);
}

const List<String> kMesesPt = [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];

String nomeMes(int mes) {
  if (mes < 1 || mes > 12) return '-';
  return kMesesPt[mes - 1];
}

/// Rótulo da pasta do empreiteiro: "Eletricista - Marcio" (especialidade e
/// nome); sem especialidade, só o nome.
String rotuloEmpreiteiro({required String especialidade, required String nome}) {
  final esp = especialidade.trim();
  final n = nome.trim();
  if (esp.isEmpty) return n;
  if (n.isEmpty) return esp;
  return '$esp - $n';
}

/// Chave estável da pasta do empreiteiro: o id quando existe, senão o nome.
String chaveEmpreiteiro(MedicaoCampoRecord m) =>
    m.empreiteiroId.trim().isNotEmpty ? m.empreiteiroId : m.empreiteiroNome;

/// Anos que têm pasta: os das medições mais as pastas criadas vazias
/// (formato `'2026'`), do mais novo pro mais antigo.
List<int> anosDasPastas(List<MedicaoCampoRecord> medicoes, Set<String> pastasVazias) {
  final anos = <int>{
    for (final m in medicoes) m.ano,
    for (final p in pastasVazias)
      if (!p.contains('|') && int.tryParse(p) != null) int.parse(p),
  };
  return anos.toList()..sort((a, b) => b.compareTo(a));
}

/// Meses (1-12) que têm pasta no ano (formato das vazias: `'2026|9'`),
/// do mais recente pro mais antigo.
List<int> mesesDasPastas(
  List<MedicaoCampoRecord> medicoes,
  Set<String> pastasVazias,
  int ano,
) {
  final meses = <int>{
    for (final m in medicoes)
      if (m.ano == ano) m.mes,
    for (final p in pastasVazias)
      if (p.startsWith('$ano|') && int.tryParse(p.split('|')[1]) != null)
        int.parse(p.split('|')[1]),
  };
  return meses.toList()..sort((a, b) => b.compareTo(a));
}

/// Medições de uma pasta ano/mês agrupadas por empreiteiro (chave -> lista).
Map<String, List<MedicaoCampoRecord>> agruparPorEmpreiteiro(
  List<MedicaoCampoRecord> medicoes,
  int ano,
  int mes,
) {
  final out = <String, List<MedicaoCampoRecord>>{};
  for (final m in medicoes) {
    if (m.ano != ano || m.mes != mes) continue;
    out.putIfAbsent(chaveEmpreiteiro(m), () => []).add(m);
  }
  return out;
}

/// Nome usado como "torre" das medições do estacionamento.
const String kTorreGaragem = 'Garagem';

/// Elementos estruturais sugeridos pro campo opcional "elementos medidos".
const List<String> kElementosMedicao = ['Laje', 'Viga', 'Pilar', 'Parede', 'Rampa'];

const List<String> kModulosGaragemPadrao = [
  'Módulo 1',
  'Módulo 2',
  'Módulo 3',
  'Módulo 4',
];

const List<String> kNiveisGaragemPadrao = ['Subsolo', 'Térreo', 'G1'];

class GaragemCelula {
  const GaragemCelula({
    required this.label,
    required this.localRef,
    required this.rank,
  });

  final String label;
  final String localRef;

  /// Posição pra ordenar: módulo e, dentro dele, o nível.
  final int rank;
}

String _slugRef(String v) {
  const from = 'áàãâäéèêëíìîïóòõôöúùûüçÁÀÃÂÄÉÈÊËÍÌÎÏÓÒÕÔÖÚÙÛÜÇ';
  const to = 'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC';
  var out = v;
  for (var i = 0; i < from.length; i++) {
    out = out.replaceAll(from[i], to[i]);
  }
  return out
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}

/// Separa as sublocais da garagem (como ficam na configuração da obra) em
/// módulos e níveis; sem nenhum dos dois, usa o padrão combinado com o
/// usuário: módulos 1 a 4 com subsolo, térreo e G1.
({List<String> modulos, List<String> niveis}) modulosENiveisDaGaragem(
  List<String> sublocais,
) {
  final modulos = <String>[];
  final niveis = <String>[];
  for (final raw in sublocais) {
    final item = raw.trim();
    final lower = item.toLowerCase();
    if (item.isEmpty) continue;
    if (lower.contains('modulo') || lower.contains('módulo')) {
      modulos.add(item);
    } else if (lower.contains('subsolo') ||
        lower.contains('terreo') ||
        lower.contains('térreo') ||
        RegExp(r'^g\d+$').hasMatch(lower)) {
      niveis.add(item);
    }
  }
  return (
    modulos: modulos.isEmpty ? kModulosGaragemPadrao : modulos,
    niveis: niveis.isEmpty ? kNiveisGaragemPadrao : niveis,
  );
}

/// Combinações módulo x nível do estacionamento, em ordem lógica.
List<GaragemCelula> celulasGaragem(List<String> modulos, List<String> niveis) {
  final out = <GaragemCelula>[];
  for (var m = 0; m < modulos.length; m++) {
    for (var n = 0; n < niveis.length; n++) {
      out.add(
        GaragemCelula(
          label: '${modulos[m]} - ${niveis[n]}',
          localRef: 'GARAGEM_${_slugRef(modulos[m])}_${_slugRef(niveis[n])}',
          rank: m * 10 + n,
        ),
      );
    }
  }
  return out;
}

/// "Execução de formas (Laje, Viga)" — serviço com os elementos, quando há.
String servicoComElementos(String servico, List<String> elementos) {
  final lista = elementos.where((e) => e.trim().isNotEmpty).toList();
  if (lista.isEmpty) return servico;
  return '$servico (${lista.join(', ')})';
}

/// Código usado quando o serviço não está no catálogo e foi digitado à mão.
const String kServicoOutro = 'OUTRO';

/// "5.4 • Execução de piso cerâmico"; serviço digitado à mão mostra só o nome.
String rotuloServico(String codigo, String nome) {
  if (codigo.trim().isEmpty || codigo == kServicoOutro) return nome;
  return '$codigo • $nome';
}

/// Depois de enviar fotos enquanto o usuário continuava editando: aproveita as
/// URLs já enviadas ([enviados]) nas fotos da versão mais nova ([atuais]).
List<MedicaoCampoApto> mesclarUrlsDeFotos(
  List<MedicaoCampoApto> atuais,
  List<MedicaoCampoApto> enviados,
) {
  final urls = <String, MedicaoCampoFoto>{};
  for (final a in enviados) {
    for (final f in a.fotos) {
      if (f.photoUrl.isNotEmpty) urls[f.id] = f;
    }
  }
  return atuais
      .map(
        (a) => a.copyWith(
          fotos: a.fotos.map((f) {
            final enviada = urls[f.id];
            if (enviada == null || f.photoUrl.isNotEmpty) return f;
            return f.copyWith(
              photoUrl: enviada.photoUrl,
              storagePath: enviada.storagePath,
              pendingSync: false,
            );
          }).toList(),
        ),
      )
      .toList();
}

/// Medição baixada da nuvem: a foto que já está neste aparelho continua
/// apontando pro arquivo local (e ganha a URL remota, se não tinha).
List<MedicaoCampoApto> preservarArquivosLocais(
  List<MedicaoCampoApto> locais,
  List<MedicaoCampoApto> remotos,
) {
  final porId = <String, MedicaoCampoFoto>{};
  for (final a in locais) {
    for (final f in a.fotos) {
      porId[f.id] = f;
    }
  }
  return remotos
      .map(
        (a) => a.copyWith(
          fotos: a.fotos.map((f) {
            final local = porId[f.id];
            if (local == null) return f;
            return local.copyWith(
              photoUrl: f.photoUrl.isNotEmpty ? f.photoUrl : local.photoUrl,
              storagePath:
                  f.storagePath.isNotEmpty ? f.storagePath : local.storagePath,
              pendingSync: false,
            );
          }).toList(),
        ),
      )
      .toList();
}

/// Partes comuns que existem em cada andar (medidas por andar, não pra torre
/// inteira): nome mostrado -> prefixo da referência.
const List<String> kPartesPorAndar = ['Hall', 'Escada', 'Elevador'];

/// "Escada - 5º andar" e a referência estável `ESCADA_5`.
({String label, String localRef}) localDoAndar(String nome, int andar) => (
  label: '$nome - $andarº andar',
  localRef: '${_slugRef(nome)}_$andar',
);
