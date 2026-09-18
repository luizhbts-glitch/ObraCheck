/// Valida o cadastro de um novo insumo de obra. Só Material é
/// estritamente necessário; endereço e estoque mínimo são livres, mas
/// não podem ser negativos quando informados.
String? validarNovoInsumo({
  required String material,
  required double estoqueMinimo,
  double? quantidadeInicial,
}) {
  if (material.trim().isEmpty) return 'Material é obrigatório.';
  if (estoqueMinimo < 0) return 'Estoque mínimo não pode ser negativo.';
  if (quantidadeInicial != null && quantidadeInicial < 0) {
    return 'Estoque inicial não pode ser negativo.';
  }
  return null;
}

/// Valida uma retirada informal: não pode ser zero/negativa nem deixar o
/// estoque negativo (miscontagem deve ser corrigida via "atualizar
/// contagem", não escondida numa retirada que zera o saldo).
String? validarRetiradaInsumo({
  required double quantidadeAtual,
  required double quantidadeRetirada,
}) {
  if (quantidadeRetirada <= 0) return 'Quantidade deve ser maior que zero.';
  if (quantidadeRetirada > quantidadeAtual) {
    return 'Estoque atual é $quantidadeAtual — não é possível retirar $quantidadeRetirada. '
        'Se a contagem estiver errada, atualize o estoque antes.';
  }
  return null;
}

/// Diferença entre o que foi contado fisicamente e o que o sistema
/// esperava — positivo quando sobra, negativo quando falta.
double calcularDivergenciaConferencia({
  required double quantidadeEsperada,
  required double quantidadeConferida,
}) {
  return quantidadeConferida - quantidadeEsperada;
}

/// Valida uma conferência de estoque: quantidade não pode ser negativa, e
/// — o ponto central do controle — toda divergência exige uma explicação
/// de quem conferiu. Não é auditoria burocrática, é registrar a ocorrência
/// ("ontem estava de atestado", por exemplo) pra quem olhar depois
/// entender o furo, não só ver um número diferente sem contexto.
String? validarConferenciaInsumo({
  required double quantidadeConferida,
  required double divergencia,
  String? observacao,
}) {
  if (quantidadeConferida < 0) return 'Quantidade não pode ser negativa.';
  if (divergencia != 0 && (observacao == null || observacao.trim().isEmpty)) {
    return 'A contagem não bateu com o estoque esperado — explique o que aconteceu '
        '(ex.: "estava de atestado, outra pessoa cobriu").';
  }
  return null;
}
