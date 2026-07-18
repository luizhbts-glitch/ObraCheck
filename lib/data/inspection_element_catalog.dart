import 'fvs_catalog.dart';

class InspectionElementRule {
  const InspectionElementRule({
    required this.requiresElement,
    required this.options,
    required this.rationale,
  });

  final bool requiresElement;
  final List<String> options;
  final String rationale;
}

class InspectionElementCatalog {
  InspectionElementCatalog._();

  static const List<String> structureElements = <String>[
    'Pilar',
    'Viga',
    'Laje',
    'Escada',
    'Bloco',
    'Baldrame',
  ];

  // Catálogo declarativo por código (V3).
  // Objetivo: reduzir heurística por profissão sem quebrar fluxo legado.
  static const Map<String, InspectionElementRule> _rulesByCode = {
    // 1.x Terraplenagem
    '1.1': InspectionElementRule(
      requiresElement: false,
      options: <String>[],
      rationale: 'Inspeção global de frente de terraplenagem.',
    ),
    '1.2': InspectionElementRule(
      requiresElement: false,
      options: <String>[],
      rationale: 'Inspeção global de frente de terraplenagem.',
    ),

    // 2.x Fundação
    '2.1': InspectionElementRule(
      requiresElement: true,
      options: structureElements,
      rationale: 'Fundação precisa separar tipos de peça por local.',
    ),
    '2.2': InspectionElementRule(
      requiresElement: true,
      options: structureElements,
      rationale: 'Fundação precisa separar tipos de peça por local.',
    ),

    // 3.x Estrutura
    '3.1': InspectionElementRule(
      requiresElement: true,
      options: structureElements,
      rationale: 'Formas estruturais variam por elemento.',
    ),
    '3.2': InspectionElementRule(
      requiresElement: true,
      options: structureElements,
      rationale: 'Armadura estrutural varia por elemento.',
    ),
    '3.3': InspectionElementRule(
      requiresElement: true,
      options: structureElements,
      rationale: 'Concretagem estrutural varia por elemento.',
    ),
    '3.4': InspectionElementRule(
      requiresElement: true,
      options: structureElements,
      rationale: 'Alvenaria estrutural pode coexistir por elemento.',
    ),

    // 4.x Alvenaria/acabamento
    '4.1': InspectionElementRule(requiresElement: false, options: <String>[], rationale: 'FVS de sistema/alvenaria de vedação por frente.'),
    '4.2': InspectionElementRule(requiresElement: false, options: <String>[], rationale: 'FVS de reboco por frente.'),
    '4.3': InspectionElementRule(requiresElement: false, options: <String>[], rationale: 'FVS de argamassa por processo.'),
    '4.4': InspectionElementRule(requiresElement: false, options: <String>[], rationale: 'FVS de revestimento por ambiente/frente.'),
    '4.5': InspectionElementRule(requiresElement: false, options: <String>[], rationale: 'FVS de monocapa por frente.'),

    // 5.x Piso/impermeabilização/cobertura/gesso
    '5.1': InspectionElementRule(requiresElement: false, options: <String>[], rationale: 'Piso industrial por área.'),
    '5.2': InspectionElementRule(requiresElement: false, options: <String>[], rationale: 'Impermeabilização por área/ambiente.'),
    '5.3': InspectionElementRule(requiresElement: false, options: <String>[], rationale: 'Cobertura por área.'),
    '5.4': InspectionElementRule(requiresElement: false, options: <String>[], rationale: 'Piso cerâmico por área.'),
    '5.5': InspectionElementRule(requiresElement: false, options: <String>[], rationale: 'Gesso acartonado por ambiente.'),
    '5.6': InspectionElementRule(requiresElement: false, options: <String>[], rationale: 'Contrapiso por área.'),
    '5.7': InspectionElementRule(requiresElement: false, options: <String>[], rationale: 'Regularização por área.'),
    '5.8': InspectionElementRule(requiresElement: false, options: <String>[], rationale: 'Impermeabilização por área/ambiente.'),

    // 6.x Esquadrias/metais
    '6.1': InspectionElementRule(requiresElement: false, options: <String>[], rationale: 'Instalação por vão/local.'),
    '6.2': InspectionElementRule(requiresElement: false, options: <String>[], rationale: 'Instalação por vão/local.'),
    '6.3': InspectionElementRule(requiresElement: false, options: <String>[], rationale: 'Instalação por trecho/local.'),
    '6.4': InspectionElementRule(requiresElement: false, options: <String>[], rationale: 'Instalação por trecho/local.'),

    // 7.x Pintura/gesso
    '7.1': InspectionElementRule(requiresElement: false, options: <String>[], rationale: 'Pintura por ambiente/frente.'),
    '7.2': InspectionElementRule(requiresElement: false, options: <String>[], rationale: 'Pintura por fachada/frente.'),
    '7.3': InspectionElementRule(requiresElement: false, options: <String>[], rationale: 'Gesso liso por ambiente.'),

    // 8.x Instalações finais
    '8.1': InspectionElementRule(requiresElement: false, options: <String>[], rationale: 'Louças/metais por ambiente.'),
    '8.2': InspectionElementRule(requiresElement: false, options: <String>[], rationale: 'Elétrica por circuito/ambiente.'),
    '8.3': InspectionElementRule(requiresElement: false, options: <String>[], rationale: 'Hidráulica por ambiente/sistema.'),
    '8.4': InspectionElementRule(requiresElement: false, options: <String>[], rationale: 'Gás por rede/ambiente.'),

    // 9.x Concreto/graute
    '9.1': InspectionElementRule(
      requiresElement: true,
      options: structureElements,
      rationale: 'Produção/aplicação em peça estrutural por elemento.',
    ),
  };

  static InspectionElementRule? ruleForCode(String code) {
    return _rulesByCode[code.trim()];
  }

  static InspectionElementRule? ruleFor(FvsTemplate template) {
    return ruleForCode(template.codigo);
  }

  static bool requiresElement(FvsTemplate template) {
    final explicit = ruleFor(template);
    if (explicit != null) return explicit.requiresElement;

    // Fallback seguro durante migração gradual da regra declarativa.
    final profissao = template.profissao.trim().toLowerCase();
    return profissao.contains('fundação') ||
        profissao.contains('carpintaria') ||
        profissao.contains('armador') ||
        profissao.contains('concretagem') ||
        profissao.contains('estrutural');
  }

  static List<String> elementsFor(FvsTemplate template) {
    final explicit = ruleFor(template);
    if (explicit != null) {
      if (!explicit.requiresElement) return const <String>[];
      return explicit.options;
    }

    if (requiresElement(template)) return structureElements;
    return const <String>[];
  }
}

