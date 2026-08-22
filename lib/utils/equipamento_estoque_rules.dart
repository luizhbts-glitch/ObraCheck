import '../models/equipamento_estoque_record.dart';

/// Valida os campos obrigatórios de um item de estoque de equipamento de
/// acordo com o tipo (regra confirmada com o usuário em 2026-08-22):
/// Próprio e De terceiro só exigem Material; Alugado exige todos os campos.
/// Retorna a mensagem de erro, ou `null` se estiver tudo válido.
String? validarCamposEquipamentoEstoque({
  required String tipo,
  required String material,
  String? terceiroNome,
  DateTime? periodoInicio,
  DateTime? periodoFim,
  String? locadora,
  String? centroCusto,
  double? valor,
}) {
  if (material.trim().isEmpty) return 'Material é obrigatório.';

  if (tipo == TipoEquipamentoEstoque.terceiro) {
    if ((terceiroNome ?? '').trim().isEmpty) {
      return 'Nome do terceiro/subcontratado é obrigatório.';
    }
  }

  if (tipo == TipoEquipamentoEstoque.alugado) {
    if (periodoInicio == null || periodoFim == null) {
      return 'Período (início e fim) é obrigatório para equipamento alugado.';
    }
    if (periodoFim.isBefore(periodoInicio)) {
      return 'Data de fim não pode ser antes da data de início.';
    }
    if ((locadora ?? '').trim().isEmpty) return 'Locadora é obrigatória.';
    if ((centroCusto ?? '').trim().isEmpty) return 'Centro de custo é obrigatório.';
    if (valor == null || valor <= 0) return 'Valor é obrigatório.';
  }

  return null;
}
