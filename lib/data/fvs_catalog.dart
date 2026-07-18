import 'fvs_data.dart';

class FvsTemplate {
  final String codigo;
  final String nome;
  final String profissao;
  final List<FvsItem> itens;

  const FvsTemplate({
    required this.codigo,
    required this.nome,
    required this.profissao,
    required this.itens,
  });
}

class FvsCatalog {
  static const List<FvsTemplate> all = [
    // ===== Terraplenagem / Escavação =====
    FvsTemplate(
      codigo: FvsData.fvs11Codigo,
      nome: FvsData.fvs11Nome,
      profissao: 'Escavação / Terraplenagem',
      itens: FvsData.fvs11Itens,
    ),
    FvsTemplate(
      codigo: FvsData.fvs12Codigo,
      nome: FvsData.fvs12Nome,
      profissao: 'Escavação / Terraplenagem',
      itens: FvsData.fvs12Itens,
    ),

    // ===== Fundação (rasa / profunda) =====
    FvsTemplate(
      codigo: FvsData.fvs21Codigo,
      nome: FvsData.fvs21Nome,
      profissao: 'Fundação (rasa/profunda)',
      itens: FvsData.fvs21Itens,
    ),
    FvsTemplate(
      codigo: FvsData.fvs22Codigo,
      nome: FvsData.fvs22Nome,
      profissao: 'Fundação (rasa/profunda)',
      itens: FvsData.fvs22Itens,
    ),

    // ===== Carpintaria =====
    FvsTemplate(
      codigo: FvsData.fvs31Codigo,
      nome: FvsData.fvs31Nome,
      profissao: 'Carpintaria',
      itens: FvsData.fvs31Itens,
    ),

    // ===== Armador =====
    FvsTemplate(
      codigo: FvsData.fvs32Codigo,
      nome: FvsData.fvs32Nome,
      profissao: 'Armador',
      itens: FvsData.fvs32Itens,
    ),

    // ===== Concretagem =====
    FvsTemplate(
      codigo: FvsData.fvs33Codigo,
      nome: FvsData.fvs33Nome,
      profissao: 'Concretagem',
      itens: FvsData.fvs33Itens,
    ),
    FvsTemplate(
      codigo: FvsData.fvs91Codigo,
      nome: FvsData.fvs91Nome,
      profissao: 'Concretagem',
      itens: FvsData.fvs91Itens,
    ),

    // ===== Bloqueiro (Alvenaria Estrutural) =====
    FvsTemplate(
      codigo: FvsData.fvs34Codigo,
      nome: FvsData.fvs34Nome,
      profissao: 'Bloqueiro (Alvenaria Estrutural)',
      itens: FvsData.fvs34Itens,
    ),

    // ===== Pedreiro de Alvenaria (Vedação) =====
    FvsTemplate(
      codigo: FvsData.fvs41Codigo,
      nome: FvsData.fvs41Nome,
      profissao: 'Pedreiro de Alvenaria (Vedação)',
      itens: FvsData.fvs41Itens,
    ),

    // ===== Pedreiro de Acabamento =====
    FvsTemplate(
      codigo: FvsData.fvs42Codigo,
      nome: FvsData.fvs42Nome,
      profissao: 'Pedreiro de Acabamento',
      itens: FvsData.fvs42Itens,
    ),
    FvsTemplate(
      codigo: FvsData.fvs43Codigo,
      nome: FvsData.fvs43Nome,
      profissao: 'Pedreiro de Acabamento',
      itens: FvsData.fvs43Itens,
    ),
    FvsTemplate(
      codigo: FvsData.fvs44Codigo,
      nome: FvsData.fvs44Nome,
      profissao: 'Pedreiro de Acabamento',
      itens: FvsData.fvs44Itens,
    ),
    FvsTemplate(
      codigo: FvsData.fvs45Codigo,
      nome: FvsData.fvs45Nome,
      profissao: 'Pedreiro de Acabamento',
      itens: FvsData.fvs45Itens,
    ),
    FvsTemplate(
      codigo: FvsData.fvs54Codigo,
      nome: FvsData.fvs54Nome,
      profissao: 'Pedreiro de Acabamento',
      itens: FvsData.fvs54Itens,
    ),
    FvsTemplate(
      codigo: FvsData.fvs56Codigo,
      nome: FvsData.fvs56Nome,
      profissao: 'Pedreiro de Acabamento',
      itens: FvsData.fvs56Itens,
    ),
    FvsTemplate(
      codigo: FvsData.fvs57Codigo,
      nome: FvsData.fvs57Nome,
      profissao: 'Pedreiro de Acabamento',
      itens: FvsData.fvs57Itens,
    ),

    // ===== Piso Industrial =====
    FvsTemplate(
      codigo: FvsData.fvs51Codigo,
      nome: FvsData.fvs51Nome,
      profissao: 'Piso Industrial',
      itens: FvsData.fvs51Itens,
    ),

    // ===== Impermeabilização =====
    FvsTemplate(
      codigo: FvsData.fvs52Codigo,
      nome: FvsData.fvs52Nome,
      profissao: 'Impermeabilização',
      itens: FvsData.fvs52Itens,
    ),
    FvsTemplate(
      codigo: FvsData.fvs58Codigo,
      nome: FvsData.fvs58Nome,
      profissao: 'Impermeabilização',
      itens: FvsData.fvs58Itens,
    ),

    // ===== Cobertura =====
    FvsTemplate(
      codigo: FvsData.fvs53Codigo,
      nome: FvsData.fvs53Nome,
      profissao: 'Cobertura',
      itens: FvsData.fvs53Itens,
    ),

    // ===== Gesso =====
    FvsTemplate(
      codigo: FvsData.fvs55Codigo,
      nome: FvsData.fvs55Nome,
      profissao: 'Gesso',
      itens: FvsData.fvs55Itens,
    ),
    FvsTemplate(
      codigo: FvsData.fvs73Codigo,
      nome: FvsData.fvs73Nome,
      profissao: 'Gesso',
      itens: FvsData.fvs73Itens,
    ),

    // ===== Esquadrias / Metais / Instalações finais =====
    FvsTemplate(
      codigo: FvsData.fvs61Codigo,
      nome: FvsData.fvs61Nome,
      profissao: 'Esquadrias / Metais',
      itens: FvsData.fvs61Itens,
    ),
    FvsTemplate(
      codigo: FvsData.fvs62Codigo,
      nome: FvsData.fvs62Nome,
      profissao: 'Esquadrias / Metais',
      itens: FvsData.fvs62Itens,
    ),
    FvsTemplate(
      codigo: FvsData.fvs63Codigo,
      nome: FvsData.fvs63Nome,
      profissao: 'Esquadrias / Metais',
      itens: FvsData.fvs63Itens,
    ),
    FvsTemplate(
      codigo: FvsData.fvs64Codigo,
      nome: FvsData.fvs64Nome,
      profissao: 'Esquadrias / Metais',
      itens: FvsData.fvs64Itens,
    ),
    FvsTemplate(
      codigo: FvsData.fvs81Codigo,
      nome: FvsData.fvs81Nome,
      profissao: 'Esquadrias / Metais',
      itens: FvsData.fvs81Itens,
    ),

    // ===== Pintura =====
    FvsTemplate(
      codigo: FvsData.fvs71Codigo,
      nome: FvsData.fvs71Nome,
      profissao: 'Pintura',
      itens: FvsData.fvs71Itens,
    ),
    FvsTemplate(
      codigo: FvsData.fvs72Codigo,
      nome: FvsData.fvs72Nome,
      profissao: 'Pintura',
      itens: FvsData.fvs72Itens,
    ),

    // ===== Elétrica =====
    FvsTemplate(
      codigo: FvsData.fvs82Codigo,
      nome: FvsData.fvs82Nome,
      profissao: 'Elétrica',
      itens: FvsData.fvs82Itens,
    ),

    // ===== Hidráulica =====
    FvsTemplate(
      codigo: FvsData.fvs83Codigo,
      nome: FvsData.fvs83Nome,
      profissao: 'Hidráulica',
      itens: FvsData.fvs83Itens,
    ),

    // ===== Gás =====
    FvsTemplate(
      codigo: FvsData.fvs84Codigo,
      nome: FvsData.fvs84Nome,
      profissao: 'Gás',
      itens: FvsData.fvs84Itens,
    ),
  ];
}