import '../services/project_settings_service.dart';

class FvsItem {
  final String descricao;
  final String dica;
  final FvsItemProofConfig proof;

  const FvsItem({
    required this.descricao,
    required this.dica,
    this.proof = const FvsItemProofConfig(),
  });
}

class FvsProofType {
  static const String visual = 'visual';
  static const String photoRequired = 'photo_required';
  static const String measurement = 'measurement';
  static const String technicalNote = 'technical_note';
  static const String sampledLocation = 'sampled_location';
}

class FvsItemProofConfig {
  final String proofType;
  final bool requiresPhoto;
  final String? measurementUnit;
  final double? measurementToleranceMin;
  final double? measurementToleranceMax;
  final bool requiresTechnicalNote;
  final bool supportsSampling;

  const FvsItemProofConfig({
    this.proofType = FvsProofType.visual,
    this.requiresPhoto = false,
    this.measurementUnit,
    this.measurementToleranceMin,
    this.measurementToleranceMax,
    this.requiresTechnicalNote = false,
    this.supportsSampling = false,
  });

  FvsItemProofConfig copyWith({
    String? proofType,
    bool? requiresPhoto,
    String? measurementUnit,
    double? measurementToleranceMin,
    double? measurementToleranceMax,
    bool? requiresTechnicalNote,
    bool? supportsSampling,
  }) {
    return FvsItemProofConfig(
      proofType: proofType ?? this.proofType,
      requiresPhoto: requiresPhoto ?? this.requiresPhoto,
      measurementUnit: measurementUnit ?? this.measurementUnit,
      measurementToleranceMin:
          measurementToleranceMin ?? this.measurementToleranceMin,
      measurementToleranceMax:
          measurementToleranceMax ?? this.measurementToleranceMax,
      requiresTechnicalNote:
          requiresTechnicalNote ?? this.requiresTechnicalNote,
      supportsSampling: supportsSampling ?? this.supportsSampling,
    );
  }
}

class FvsData {
  // =========================
  // 1.1 Movimentação de terra
  // =========================
  static const String fvs11Codigo = '1.1';
  static const String fvs11Nome = 'Movimentação de terra';

  static const List<FvsItem> fvs11Itens = [
    FvsItem(
      descricao: 'Condição climática adequada para execução',
      dica: 'Verificar chuva/solo encharcado; registrar se houve interrupção.',
    ),
    FvsItem(
      descricao: 'Demarcação das cotas topográficas',
      dica: 'Conferir marcações/estacas e referência de nível (RN).',
    ),
    FvsItem(
      descricao: 'Ensaio de laboratório / controle tecnológico',
      dica: 'Conferir resultados e frequência conforme plano da obra.',
    ),
    FvsItem(
      descricao: 'Execução por camadas de compactação',
      dica: 'Verificar espessura das camadas e equipamento utilizado.',
    ),
    FvsItem(
      descricao: 'Cotas finais (nível final atingido)',
      dica: 'Conferir com nível/laser e comparar com projeto.',
    ),
    FvsItem(
      descricao: 'Inclinação / taludes conforme previsto',
      dica: 'Verificar caimentos e estabilidade de taludes.',
    ),
    FvsItem(
      descricao: 'Acabamento final e limpeza da área',
      dica: 'Inspeção visual; verificar sobras e regularidade do terreno.',
    ),
  ];

  // =========================
  // 1.2 Movimentação de terra (igual 1.1)
  // =========================
  static const String fvs12Codigo = '1.2';
  static const String fvs12Nome = 'Movimentação de terra';

  static const List<FvsItem> fvs12Itens = fvs11Itens;

  // =========================
  // 2.1 Fundação rasa
  // =========================
  static const String fvs21Codigo = '2.1';
  static const String fvs21Nome = 'Execução de fundação rasa';

  static const List<FvsItem> fvs21Itens = [
    FvsItem(
      descricao: 'Limpeza do terreno / área de trabalho',
      dica: 'Verificar remoção de material solto e preparação da base.',
    ),
    FvsItem(
      descricao: 'Locação conforme projeto',
      dica: 'Conferir eixos, cotas e gabarito; registrar conferência.',
    ),
    FvsItem(
      descricao: 'Escavação conforme dimensões e cotas',
      dica: 'Conferir profundidade/largura e estabilidade do fundo.',
    ),
    FvsItem(
      descricao: 'Prumo e excentricidade conforme projeto',
      dica: 'Verificar alinhamento/posição de elementos (sapatas/blocos).',
    ),
    FvsItem(
      descricao: 'Armação conforme detalhamento',
      dica: 'Conferir bitolas, espaçamentos, cobrimento e amarrações.',
    ),
    FvsItem(
      descricao: 'Concretagem conforme procedimento',
      dica: 'Conferir lançamento, adensamento e cura inicial.',
    ),
  ];

  // =========================
  // 2.2 Fundação profunda (você citou depois; incluí no catálogo)
  // =========================
  static const String fvs22Codigo = '2.2';
  static const String fvs22Nome = 'Execução de fundação profunda';

  static const List<FvsItem> fvs22Itens = [
    FvsItem(
      descricao: 'Condições de início e locação',
      dica: 'Verificar eixos, marcações e liberação de frente.',
    ),
    FvsItem(
      descricao: 'Escavação conforme projeto (profundidade/diâmetro)',
      dica: 'Conferir medidas e integridade das paredes da escavação.',
    ),
    FvsItem(
      descricao: 'Prumo e excentricidade',
      dica: 'Checar verticalidade e posição do furo/estaca.',
    ),
    FvsItem(
      descricao: 'Armação conforme detalhamento',
      dica: 'Conferir bitolas, espaçamentos, emendas e cobrimento.',
    ),
    FvsItem(
      descricao: 'Concretagem conforme procedimento',
      dica: 'Conferir lançamento contínuo, adensamento e registros.',
    ),
  ];

  // =========================
  // 3.1 Formas
  // =========================
  static const String fvs31Codigo = '3.1';
  static const String fvs31Nome = 'Execução de formas';

  static const List<FvsItem> fvs31Itens = [
    FvsItem(
      descricao: 'Alinhamento',
      dica: 'Conferir eixos e alinhamento com trena/linha/laser.',
    ),
    FvsItem(
      descricao: 'Dimensão conforme projeto',
      dica: 'Verificar largura/altura/espessura dos elementos.',
    ),
    FvsItem(
      descricao: 'Travamento das formas',
      dica: 'Checar escoras, travas e rigidez (sem “barriga”).',
    ),
    FvsItem(
      descricao: 'Nivelamento',
      dica: 'Conferir nível com laser/mangueira.',
    ),
    FvsItem(
      descricao: 'Prumo',
      dica: 'Conferir verticalidade com prumo/nível.',
    ),
    FvsItem(
      descricao: 'Escoramento',
      dica: 'Checar base firme, espaçamento e segurança do escoramento.',
    ),
  ];

  // =========================
  // 3.2 Armaduras
  // =========================
  static const String fvs32Codigo = '3.2';
  static const String fvs32Nome = 'Montagem de armaduras';

  static const List<FvsItem> fvs32Itens = [
    FvsItem(
      descricao: 'Condição de início / material disponível',
      dica: 'Conferir aço, espaçadores e projeto em mãos.',
    ),
    FvsItem(
      descricao: 'Corte e dobra conforme projeto',
      dica: 'Checar comprimentos, dobras e identificação.',
    ),
    FvsItem(
      descricao: 'Checagem da armadura montada',
      dica: 'Conferir bitolas, espaçamentos e amarrações.',
    ),
    FvsItem(
      descricao: 'Posicionamento e cobrimento',
      dica: 'Verificar cobrimento com espaçadores; evitar contato com forma.',
    ),
    FvsItem(
      descricao: 'Checagem das esperas',
      dica: 'Conferir posições, comprimentos e amarração das esperas.',
    ),
  ];

  // =========================
  // 3.3 Concretagem estrutural
  // =========================
  static const String fvs33Codigo = '3.3';
  static const String fvs33Nome = 'Concretagem de peça estrutural';

  static const List<FvsItem> fvs33Itens = [
    FvsItem(
      descricao: 'Preparação da frente de trabalho',
      dica: 'Verificar acesso, limpeza e equipe/equipamentos.',
    ),
    FvsItem(
      descricao: 'Controle tecnológico',
      dica: 'Conferir slump, corpos de prova e registros.',
    ),
    FvsItem(
      descricao: 'Escoramento liberado e conferido',
      dica: 'Checar travamentos e segurança antes do lançamento.',
    ),
    FvsItem(
      descricao: 'Adensamento do concreto',
      dica: 'Usar vibrador corretamente; evitar segregação e vazios.',
    ),
    FvsItem(
      descricao: 'Limpeza e acabamento',
      dica: 'Verificar acabamento e limpeza de respingos/sobras.',
    ),
    FvsItem(
      descricao: 'Desforma / deslocamento de peças (quando aplicável)',
      dica: 'Respeitar prazo e procedimento; registrar ocorrência.',
    ),
  ];

  // =========================
  // 3.4 Alvenaria estrutural
  // =========================
  static const String fvs34Codigo = '3.4';
  static const String fvs34Nome = 'Execução de alvenaria estrutural';

  static const List<FvsItem> fvs34Itens = [
    FvsItem(
      descricao: 'Nivelamento e alinhamento',
      dica: 'Conferir fiadas com nível/linha; registrar desvios.',
    ),
    FvsItem(
      descricao: 'Verificação de graute',
      dica: 'Conferir pontos de grauteamento e preenchimento.',
    ),
    FvsItem(
      descricao: 'Verificação de medidas',
      dica: 'Conferir vãos, dimensões e posicionamento conforme projeto.',
    ),
    FvsItem(
      descricao: 'Aspecto final',
      dica: 'Verificar prumo, juntas e acabamento geral.',
    ),
  ];

  // =========================
  // 4.1 Alvenaria não estrutural
  // =========================
  static const String fvs41Codigo = '4.1';
  static const String fvs41Nome = 'Execução de alvenaria não estrutural';

  static const List<FvsItem> fvs41Itens = [
    FvsItem(
      descricao: 'Nivelamento e alinhamento da fiada de marcação',
      dica: 'Conferir primeira fiada com nível/linha e referência de projeto.',
    ),
    FvsItem(
      descricao: 'Planeza e prumo da alvenaria',
      dica: 'Conferir com régua 2m e prumo; registrar pontos fora.',
    ),
    FvsItem(
      descricao: 'Largura, altura e alinhamento dos vãos (portas/janelas)',
      dica: 'Conferir medidas e esquadro; comparar com projeto.',
    ),
    FvsItem(
      descricao: 'Aspecto final e fixação',
      dica:
          'Inspeção visual; verificar amarrações/encunhamento quando previsto.',
    ),
    FvsItem(
      descricao: 'Atendimento à ABNT NBR 15575 (desempenho) – quando aplicável',
      dica:
          'Conferir requisitos de vedação/acústica conforme detalhamento adotado.',
    ),
    FvsItem(
      descricao: 'Atendimento à ABNT NBR 15575 (incêndio) – quando aplicável',
      dica:
          'Conferir especificação de materiais e espessuras conforme projeto.',
    ),
    FvsItem(
      descricao: 'Espessura / assentamento conforme padrão',
      dica:
          'Conferir assentamento e espessura típica (ex: 1 cm se for o padrão da obra).',
    ),
  ];

  // =========================
  // 4.2 Reboco (se você já tem no seu arquivo, pode manter o seu e apagar este)
  // =========================
  static const String fvs42Codigo = '4.2';
  static const String fvs42Nome = 'Execução de reboco';

  static const List<FvsItem> fvs42Itens = [
    FvsItem(
      descricao: 'Preparação da base',
      dica: 'Base limpa, sem poeira/óleo; umedecimento quando necessário.',
    ),
    FvsItem(
      descricao: 'Prumo das taliscas',
      dica: 'Conferir prumo e alinhamento das taliscas com prumo/linha.',
    ),
    FvsItem(
      descricao: 'Planicidade e aspecto final',
      dica: 'Conferir com régua 2m; verificar ondulações e acabamento.',
    ),
    FvsItem(
      descricao: 'Atendimento ABNT NBR 15575 (quando aplicável)',
      dica: 'Conferir espessuras e execução conforme padrão definido.',
    ),
  ];

  // =========================
  // 4.3 Produção de argamassa
  // =========================
  static const String fvs43Codigo = '4.3';
  static const String fvs43Nome = 'Produção de argamassa';

  static const List<FvsItem> fvs43Itens = [
    FvsItem(
      descricao: 'Traço conforme especificação',
      dica: 'Conferir dosagens e registro do traço.',
    ),
    FvsItem(
      descricao: 'Homogeneidade',
      dica: 'Verificar mistura uniforme, sem “pelotas” ou segregação.',
    ),
    FvsItem(
      descricao: 'Consistência / trabalhabilidade',
      dica: 'Verificar ponto e ajuste de água; registrar variações.',
    ),
  ];

  // =========================
  // 4.4 Revestimento cerâmico interno
  // =========================
  static const String fvs44Codigo = '4.4';
  static const String fvs44Nome = 'Execução de revestimento cerâmico interno';

  static const List<FvsItem> fvs44Itens = [
    FvsItem(
      descricao: 'Planicidade da base e do revestimento',
      dica: 'Conferir com régua 2m; checar degraus.',
    ),
    FvsItem(
      descricao: 'Espessura das juntas',
      dica: 'Conferir espaçadores e padrão de junta.',
    ),
    FvsItem(
      descricao: 'Aderência das placas',
      dica: 'Conferir dupla colagem quando aplicável e “som cavo”.',
    ),
    FvsItem(
      descricao: 'Acabamento',
      dica: 'Verificar cortes, cantos, encontros e arremates.',
    ),
    FvsItem(
      descricao: 'Aspecto final',
      dica: 'Verificar alinhamento, paginação e limpeza final.',
    ),
  ];

  // =========================
  // 4.5 Monocapa
  // =========================
  static const String fvs45Codigo = '4.5';
  static const String fvs45Nome = 'Execução de monocapa';

  static const List<FvsItem> fvs45Itens = [
    FvsItem(
      descricao: 'Preparação da superfície',
      dica: 'Base limpa/regular, sem pó e sem partes soltas.',
    ),
    FvsItem(
      descricao: 'Regularização',
      dica: 'Verificar correções antes da aplicação.',
    ),
    FvsItem(
      descricao: 'Aspecto geral / materiais corretos',
      dica: 'Conferir materiais e validade; registrar lote.',
    ),
    FvsItem(
      descricao: 'Aplicação da primeira camada',
      dica: 'Verificar espessura e aderência.',
    ),
    FvsItem(
      descricao: 'Aplicação da segunda camada',
      dica: 'Conferir uniformidade e acabamento.',
    ),
    FvsItem(
      descricao: 'Finalização',
      dica: 'Verificar textura/acabamento e cura conforme orientação.',
    ),
  ];

  // =========================
  // 5.1 Piso de concreto polido
  // =========================
  static const String fvs51Codigo = '5.1';
  static const String fvs51Nome = 'Execução de piso de concreto polido';

  static const List<FvsItem> fvs51Itens = [
    FvsItem(
      descricao: 'Nível das taliscas',
      dica: 'Conferir nível/laser e referências.',
    ),
    FvsItem(
      descricao: 'Aspecto geral do acabamento',
      dica: 'Verificar uniformidade, queima e “marcas”.',
    ),
    FvsItem(
      descricao: 'Cortes e juntas de dilatação',
      dica: 'Conferir posicionamento, profundidade e alinhamento.',
    ),
    FvsItem(
      descricao: 'Caimento (quando houver)',
      dica: 'Conferir caimentos previstos (áreas molhadas).',
    ),
    FvsItem(
      descricao: 'Junta fria',
      dica: 'Verificar localização e tratamento adequado.',
    ),
  ];

  // =========================
  // 5.2 Impermeabilização com manta asfáltica
  // =========================
  static const String fvs52Codigo = '5.2';
  static const String fvs52Nome =
      'Execução de impermeabilização com manta asfáltica';

  static const List<FvsItem> fvs52Itens = [
    FvsItem(
      descricao: 'Preparação da superfície',
      dica: 'Base regular, limpa e seca; primer quando necessário.',
    ),
    FvsItem(
      descricao: 'Caimentos de áreas molhadas',
      dica: 'Conferir caimento antes da manta.',
    ),
    FvsItem(
      descricao: 'Aplicação da impermeabilização',
      dica: 'Conferir sobreposições, cantos, ralos e arremates.',
    ),
    FvsItem(
      descricao: 'Estanqueidade',
      dica: 'Realizar teste (ex: lâmina d’água) conforme procedimento.',
    ),
    FvsItem(
      descricao: 'Junta fria / emendas',
      dica: 'Conferir tratamento e solda/aderência das emendas.',
    ),
  ];

  // =========================
  // 5.3 Cobertura com telha fibrocimento
  // =========================
  static const String fvs53Codigo = '5.3';
  static const String fvs53Nome =
      'Execução de cobertura com telha fibrocimento';

  static const List<FvsItem> fvs53Itens = [
    FvsItem(
      descricao: 'Nível das taliscas / estrutura',
      dica: 'Conferir nível e alinhamento da estrutura de apoio.',
    ),
    FvsItem(
      descricao: 'Acabamento de superfície / fixações',
      dica: 'Conferir parafusos, arruelas e vedação.',
    ),
    FvsItem(
      descricao: 'Caimento das áreas',
      dica: 'Conferir inclinação conforme especificação.',
    ),
    FvsItem(
      descricao: 'Planicidade',
      dica: 'Inspeção visual; verificar empenos e alinhamento das telhas.',
    ),
    FvsItem(
      descricao: 'Impermeabilização / arremates',
      dica: 'Conferir rufos, cumeeiras e pontos críticos.',
    ),
  ];

  // =========================
  // 5.4 Piso cerâmico
  // =========================
  static const String fvs54Codigo = '5.4';
  static const String fvs54Nome = 'Execução de piso cerâmico';

  static const List<FvsItem> fvs54Itens = [
    FvsItem(
      descricao: 'Aspecto geral',
      dica: 'Verificar paginação, cortes e alinhamento.',
    ),
    FvsItem(
      descricao: 'Rejuntamento e limpeza',
      dica: 'Conferir preenchimento e limpeza final.',
    ),
    FvsItem(
      descricao: 'Planicidade',
      dica: 'Verificar degraus entre peças e régua 2m.',
    ),
    FvsItem(
      descricao: 'Rodapé',
      dica: 'Conferir altura, alinhamento e acabamento.',
    ),
    FvsItem(
      descricao: 'Caimento (áreas molhadas)',
      dica: 'Conferir caimento até ralo conforme projeto.',
    ),
  ];

  // =========================
  // 5.5 Gesso acartonado
  // =========================
  static const String fvs55Codigo = '5.5';
  static const String fvs55Nome = 'Execução de gesso acartonado';

  static const List<FvsItem> fvs55Itens = [
    FvsItem(
      descricao: 'Placas de gesso conforme especificação',
      dica: 'Conferir tipo de placa e integridade.',
    ),
    FvsItem(
      descricao: 'Encaixe e fixação das placas',
      dica: 'Conferir espaçamento de parafusos e estrutura.',
    ),
    FvsItem(
      descricao: 'Juntas',
      dica: 'Conferir tratamento de juntas e fitas.',
    ),
    FvsItem(
      descricao: 'Acabamento',
      dica: 'Verificar nivelamento, quinas e lixamento.',
    ),
  ];

  // =========================
  // 5.6 Contrapiso
  // =========================
  static const String fvs56Codigo = '5.6';
  static const String fvs56Nome = 'Execução de contrapiso';

  static const List<FvsItem> fvs56Itens = [
    FvsItem(
      descricao: 'Nível das taliscas',
      dica: 'Conferir nível/laser e espessura.',
    ),
    FvsItem(
      descricao: 'Acabamento das superfícies',
      dica: 'Verificar regularidade e sem “buracos”.',
    ),
    FvsItem(
      descricao: 'Caimento das áreas molhadas',
      dica: 'Conferir inclinação para ralos.',
    ),
    FvsItem(
      descricao: 'Aderência com a base',
      dica: 'Conferir ponte de aderência/chapisco quando aplicável.',
    ),
    FvsItem(
      descricao: 'Atendimento ABNT NBR 15575 (quando aplicável)',
      dica: 'Conferir padrão definido pela obra.',
    ),
    FvsItem(
      descricao: 'Ensaio de 72h (quando aplicável)',
      dica: 'Realizar/registrar conforme procedimento interno.',
    ),
  ];

  // =========================
  // 5.7 Regularização (COMPLETADO)
  // =========================
  static const String fvs57Codigo = '5.7';
  static const String fvs57Nome = 'Execução de regularização';

  static const List<FvsItem> fvs57Itens = [
    FvsItem(
      descricao: 'Preparação da superfície',
      dica:
          'Base limpa, sem pó/óleo, sem partes soltas; umedecer quando necessário.',
    ),
    FvsItem(
      descricao: 'Materiais e traço conforme padrão da obra',
      dica: 'Conferir dosagem/argamassa e validade; registrar o traço adotado.',
    ),
    FvsItem(
      descricao: 'Espessura conforme previsto',
      dica: 'Conferir espessura média e pontos críticos (ralos/soleiras).',
    ),
    FvsItem(
      descricao: 'Nível e planicidade',
      dica: 'Conferir com régua 2m e nível/laser; registrar desvios.',
    ),
    FvsItem(
      descricao: 'Caimentos (áreas molhadas)',
      dica: 'Conferir inclinação para ralos; verificar sem “barrigas”.',
    ),
    FvsItem(
      descricao: 'Aderência à base',
      dica:
          'Conferir ponte de aderência/chapisco quando aplicável; evitar destacamentos.',
    ),
    FvsItem(
      descricao: 'Cura e proteção',
      dica:
          'Verificar cura úmida/proteção contra tráfego e impactos no período inicial.',
    ),
    FvsItem(
      descricao: 'Acabamento final e limpeza',
      dica: 'Inspeção visual; superfície uniforme e pronta para próxima etapa.',
    ),
  ];

  // =========================
  // 5.8 Impermeabilização com cimento polimérico
  // =========================
  static const String fvs58Codigo = '5.8';
  static const String fvs58Nome =
      'Execução de impermeabilização com cimento polimérico';

  static const List<FvsItem> fvs58Itens = [
    FvsItem(
      descricao: 'Preparação da superfície',
      dica: 'Base regular, limpa e sem partes soltas.',
    ),
    FvsItem(
      descricao: 'Aplicação da impermeabilização',
      dica: 'Conferir demãos, cantos, ralos e arremates.',
    ),
    FvsItem(
      descricao: 'Estanqueidade',
      dica: 'Realizar teste conforme procedimento (quando aplicável).',
    ),
  ];

  // =========================
  // 6.1 Janelas
  // =========================
  static const String fvs61Codigo = '6.1';
  static const String fvs61Nome = 'Instalação de janelas';

  static const List<FvsItem> fvs61Itens = [
    FvsItem(
      descricao: 'Condição de início (vão preparado)',
      dica: 'Conferir vão limpo, medidas e contramarco (se houver).',
    ),
    FvsItem(
      descricao: 'Chumbamento / fixação',
      dica: 'Conferir pontos e método de fixação.',
    ),
    FvsItem(
      descricao: 'Peitoril',
      dica: 'Conferir nivelamento, vedação e acabamento.',
    ),
    FvsItem(
      descricao: 'Enchimento / vedação',
      dica: 'Verificar espuma/argamassa/silicone conforme padrão.',
    ),
    FvsItem(
      descricao: 'Funcionamento',
      dica:
          'Abrir/fechar; verificar travas, alinhamento e estanqueidade básica.',
    ),
  ];

  // =========================
  // 6.2 Kit porta pronta
  // =========================
  static const String fvs62Codigo = '6.2';
  static const String fvs62Nome = 'Execução de kit porta pronta';

  static const List<FvsItem> fvs62Itens = [
    FvsItem(
      descricao: 'Esquadro, prumo e nível',
      dica: 'Conferir marco/alizar com nível e esquadro.',
    ),
    FvsItem(
      descricao: 'Fixação',
      dica: 'Conferir parafusos/espumas e firmeza do conjunto.',
    ),
    FvsItem(
      descricao: 'Lado de abertura',
      dica: 'Conferir sentido de abertura conforme projeto.',
    ),
    FvsItem(
      descricao: 'Alizares',
      dica: 'Conferir encaixe, alinhamento e acabamento.',
    ),
    FvsItem(
      descricao: 'Acabamento',
      dica: 'Verificar frestas, vedação e limpeza.',
    ),
    FvsItem(
      descricao: 'Funcionamento',
      dica: 'Verificar fechadura, dobradiças e fechamento suave.',
    ),
  ];

  // =========================
  // 6.3 Corrimão
  // =========================
  static const String fvs63Codigo = '6.3';
  static const String fvs63Nome = 'Instalação de corrimão';

  static const List<FvsItem> fvs63Itens = [
    FvsItem(
      descricao: 'Fixação',
      dica: 'Conferir chumbadores/parafusos e firmeza.',
    ),
    FvsItem(
      descricao: 'Espaçamento e dimensão',
      dica: 'Conferir altura e afastamentos conforme padrão/projeto.',
    ),
  ];

  // =========================
  // 6.4 Guarda-corpo
  // =========================
  static const String fvs64Codigo = '6.4';
  static const String fvs64Nome = 'Execução de guarda-corpo';

  static const List<FvsItem> fvs64Itens = [
    FvsItem(
      descricao: 'Altura e dimensão',
      dica: 'Conferir altura e espaçamentos conforme norma/projeto.',
    ),
    FvsItem(
      descricao: 'Vidro (quando houver)',
      dica: 'Conferir integridade, espessura e fixação.',
    ),
    FvsItem(descricao: 'Fixação', dica: 'Checar chumbadores, base e firmeza.'),
  ];

  // =========================
  // 7.1 Pintura interna
  // =========================
  static const String fvs71Codigo = '7.1';
  static const String fvs71Nome = 'Execução de pintura interna';

  static const List<FvsItem> fvs71Itens = [
    FvsItem(
      descricao: 'Preparação da superfície',
      dica: 'Verificar massa/lixamento, limpeza e correções.',
    ),
    FvsItem(
      descricao: 'Execução de recortes',
      dica: 'Conferir cantos, encontros e proteção.',
    ),
    FvsItem(
      descricao: 'Aspecto geral',
      dica: 'Uniformidade, cobertura e ausência de manchas.',
    ),
    FvsItem(
      descricao: 'Limpeza do ambiente',
      dica: 'Verificar respingos, proteção removida e ambiente limpo.',
    ),
  ];

  // =========================
  // 7.2 Pintura externa
  // =========================
  static const String fvs72Codigo = '7.2';
  static const String fvs72Nome = 'Execução de pintura externa';

  static const List<FvsItem> fvs72Itens = [
    FvsItem(
      descricao: 'Preparação da superfície',
      dica: 'Conferir limpeza, correções e base adequada.',
    ),
    FvsItem(
      descricao: 'Fissuras',
      dica: 'Verificar tratamento de fissuras antes da pintura.',
    ),
    FvsItem(
      descricao: 'Aspecto geral',
      dica: 'Uniformidade e cobertura; sem manchas/bolhas.',
    ),
    FvsItem(
      descricao: 'Limpeza do ambiente',
      dica: 'Verificar proteção e limpeza final.',
    ),
  ];

  // =========================
  // 7.3 Gesso liso
  // =========================
  static const String fvs73Codigo = '7.3';
  static const String fvs73Nome = 'Execução de gesso liso';

  static const List<FvsItem> fvs73Itens = [
    FvsItem(
      descricao: 'Planeza',
      dica: 'Verificar com régua 2m; registrar ondulações.',
    ),
    FvsItem(
      descricao: 'Prumo',
      dica: 'Conferir verticalidade em pontos amostrados.',
    ),
    FvsItem(
      descricao: 'Pontos elétricos',
      dica: 'Verificar recortes e acabamentos em caixas.',
    ),
    FvsItem(
      descricao: 'Quinas e cantos',
      dica: 'Conferir definição e resistência ao toque.',
    ),
    FvsItem(
      descricao: 'Acabamento',
      dica: 'Verificar uniformidade e sem marcas excessivas.',
    ),
    FvsItem(
      descricao: 'Limpeza do ambiente',
      dica: 'Verificar remoção de pó e respingos.',
    ),
  ];

  // =========================
  // 8.1 Bancadas, louças e metais
  // =========================
  static const String fvs81Codigo = '8.1';
  static const String fvs81Nome =
      'Assentamento de bancadas, louças e metais sanitários';

  static const List<FvsItem> fvs81Itens = [
    FvsItem(
      descricao: 'Bancada - nível da chumbada',
      dica: 'Conferir referência e suporte antes de fixar.',
    ),
    FvsItem(
      descricao: 'Bancada - nível da bancada',
      dica: 'Conferir nível e alinhamento final.',
    ),
    FvsItem(
      descricao: 'Bancada - limpeza das peças e rejunte',
      dica: 'Verificar acabamento e limpeza final.',
    ),
    FvsItem(
      descricao: 'Louças - fixação do vaso',
      dica: 'Conferir fixação e estabilidade.',
    ),
    FvsItem(
      descricao: 'Louças - fixação das louças',
      dica: 'Conferir fixação e vedação.',
    ),
    FvsItem(
      descricao: 'Louças - rejunte e estanqueidade',
      dica: 'Conferir selagens e possíveis vazamentos.',
    ),
    FvsItem(
      descricao: 'Metais - fixação',
      dica: 'Conferir aperto, alinhamento e acabamento.',
    ),
    FvsItem(
      descricao: 'Metais - teste de estanqueidade e limpeza',
      dica: 'Testar funcionamento e vazamentos; limpar peças.',
    ),
    FvsItem(
      descricao: 'Atendimento norma / carga 40kg (quando aplicável)',
      dica: 'Verificar procedimento adotado e registrar teste.',
    ),
  ];

  // =========================
  // 8.2 Instalação elétrica
  // =========================
  static const String fvs82Codigo = '8.2';
  static const String fvs82Nome = 'Execução de instalação elétrica';

  static const List<FvsItem> fvs82Itens = [
    FvsItem(
      descricao: 'Furos de passagem',
      dica: 'Conferir furos conforme projeto e proteção de bordas.',
    ),
    FvsItem(
      descricao: 'Caixas elétricas e eletrodutos',
      dica: 'Conferir alinhamento, fixação e posições.',
    ),
    FvsItem(
      descricao: 'Tubulação',
      dica: 'Conferir diâmetro, continuidade e fixação.',
    ),
    FvsItem(
      descricao: 'Quadros elétricos',
      dica: 'Conferir fixação, identificação e organização.',
    ),
    FvsItem(
      descricao: 'Tomadas, pontos de luz e interruptores',
      dica: 'Conferir funcionamento, altura e acabamento.',
    ),
  ];

  // =========================
  // 8.3 Instalação hidráulica
  // =========================
  static const String fvs83Codigo = '8.3';
  static const String fvs83Nome = 'Execução de instalação hidráulica';

  static const List<FvsItem> fvs83Itens = [
    FvsItem(
      descricao: 'Furos / passagens',
      dica: 'Conferir abertura e proteção conforme projeto.',
    ),
    FvsItem(
      descricao: 'Prumadas',
      dica: 'Conferir alinhamento, fixação e identificação.',
    ),
    FvsItem(
      descricao: 'Distribuição',
      dica: 'Conferir trajetos, conexões e registros.',
    ),
    FvsItem(
      descricao: 'Proteção',
      dica: 'Conferir proteção de tubulações e pontos vulneráveis.',
    ),
    FvsItem(
      descricao: 'Instalação de peças',
      dica: 'Conferir instalação de registros/caixas/sifões quando aplicável.',
    ),
    FvsItem(
      descricao: 'Fixação e estanqueidade',
      dica: 'Testar vazamentos; registrar teste de pressão/estanqueidade.',
    ),
    FvsItem(
      descricao: 'Fixação da tubulação',
      dica: 'Conferir abraçadeiras e espaçamentos.',
    ),
  ];

  // =========================
  // 8.4 Instalação de gás
  // =========================
  static const String fvs84Codigo = '8.4';
  static const String fvs84Nome = 'Execução de instalação de gás';

  static const List<FvsItem> fvs84Itens = [
    FvsItem(
      descricao: 'Cotas / posicionamento',
      dica: 'Conferir altura, localização e trajeto conforme projeto.',
    ),
    FvsItem(
      descricao: 'Teste de estanqueidade',
      dica: 'Executar teste e registrar pressão/tempo conforme procedimento.',
    ),
  ];

  // =========================
  // 9.1 Produção de concreto e graute em obra
  // =========================
  static const String fvs91Codigo = '9.1';
  static const String fvs91Nome = 'Produção de concreto e graute em obra';

  static const List<FvsItem> fvs91Itens = [
    FvsItem(
      descricao: 'Traço conforme especificação',
      dica: 'Conferir dosagem e registro do traço.',
    ),
    FvsItem(
      descricao: 'Homogeneidade',
      dica: 'Verificar mistura uniforme e tempo de mistura.',
    ),
    FvsItem(
      descricao: 'Consistência',
      dica: 'Verificar abatimento/trabalhabilidade conforme padrão.',
    ),
  ];
}

class FvsProofCatalog {
  FvsProofCatalog._();

  static const List<FvsItemProofConfig> _fvs45FacadeProofs = [
    FvsItemProofConfig(proofType: FvsProofType.visual),
    FvsItemProofConfig(
      proofType: FvsProofType.photoRequired,
      requiresPhoto: true,
    ),
    FvsItemProofConfig(
      proofType: FvsProofType.measurement,
      measurementUnit: 'mm',
      requiresPhoto: true,
    ),
    FvsItemProofConfig(
      proofType: FvsProofType.photoRequired,
      requiresPhoto: true,
    ),
    FvsItemProofConfig(proofType: FvsProofType.visual),
    FvsItemProofConfig(
      proofType: FvsProofType.photoRequired,
      requiresPhoto: true,
    ),
  ];

  static const List<FvsItemProofConfig> _fvs45UnitProofs = [
    FvsItemProofConfig(proofType: FvsProofType.visual),
    FvsItemProofConfig(
      proofType: FvsProofType.photoRequired,
      requiresPhoto: true,
    ),
    FvsItemProofConfig(
      proofType: FvsProofType.measurement,
      measurementUnit: 'mm',
      requiresPhoto: true,
    ),
    FvsItemProofConfig(
      proofType: FvsProofType.photoRequired,
      requiresPhoto: true,
    ),
    FvsItemProofConfig(proofType: FvsProofType.visual),
    FvsItemProofConfig(
      proofType: FvsProofType.photoRequired,
      requiresPhoto: true,
    ),
  ];

  static FvsItemProofConfig resolveForItem({
    required String fvsCode,
    required int itemIndex,
    String? locationContext,
    FvsItemProofConfig? fallback,
  }) {
    return resolveForItemWithOverride(
      fvsCode: fvsCode,
      itemIndex: itemIndex,
      locationContext: locationContext,
      fallback: fallback,
    );
  }

  static FvsItemProofConfig resolveForItemWithOverride({
    required String fvsCode,
    required int itemIndex,
    String? locationContext,
    FvsItemProofConfig? fallback,
    bool? proofPhotoOverride,
  }) {
    final code = fvsCode.trim();
    final context = (locationContext ?? '').trim().toLowerCase();
    final base = fallback ?? const FvsItemProofConfig();

    if (code != FvsData.fvs45Codigo) {
      return _applyOverride(base, proofPhotoOverride);
    }

    final list = context == 'facade' ? _fvs45FacadeProofs : _fvs45UnitProofs;
    if (itemIndex < 0 || itemIndex >= list.length) {
      return _applyOverride(base, proofPhotoOverride);
    }
    return _applyOverride(list[itemIndex], proofPhotoOverride);
  }

  static FvsItemProofConfig _applyOverride(
    FvsItemProofConfig config,
    bool? override,
  ) {
    if (override == null) return config;
    return config.copyWith(requiresPhoto: override);
  }

  static FvsItemProofConfig resolveForProject({
    required String fvsCode,
    required int itemIndex,
    String? locationContext,
    FvsItemProofConfig? fallback,
  }) {
    final projectSettings = _safeCurrentProjectSettings();
    final override =
        projectSettings?.fvsProofPhotoOverrides[fvsCode.trim()]?[itemIndex];
    return resolveForItemWithOverride(
      fvsCode: fvsCode,
      itemIndex: itemIndex,
      locationContext: locationContext,
      fallback: fallback,
      proofPhotoOverride: override,
    );
  }

  static dynamic _safeCurrentProjectSettings() {
    try {
      return ProjectSettingsService.instance.currentProjectSettingsSync;
    } catch (_) {
      return null;
    }
  }
}
