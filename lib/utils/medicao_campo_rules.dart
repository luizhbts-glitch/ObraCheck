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
    'Obra: ${orDash(obra)} | Torre: ${orDash(torre)} | Apto: ${orDash(apto)}',
    'Serviço: ${orDash(servico)} | Empreiteiro: ${orDash(empreiteiro)}',
    '${formatMedicaoDataHora(dataHora)} | Usuário: ${orDash(usuario)}',
  ];
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
}) {
  if (servicoCodigo.trim().isEmpty) return 'Escolha o serviço.';
  if (empreiteiroNome.trim().isEmpty) return 'Escolha o empreiteiro.';
  if (totalAptosSelecionados < 1) {
    return 'Marque ao menos um apartamento.';
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
