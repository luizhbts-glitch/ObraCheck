import '../models/employee_record.dart';
import '../models/perfil_acesso_record.dart';

/// Resolução de permissão granular do ERP (módulo > entidade > ação).
///
/// Duas regras fixas, decididas em 2026-07-18:
/// - Override por pessoa sempre vence o que o perfil diz (pra liberar ou
///   pra revogar).
/// - Ninguém concede o que não tem: `canGrant` usa a mesma resolução de
///   quem está concedendo, então uma pessoa nunca consegue dar a outra uma
///   permissão que ela mesma não possui.

/// Permissão efetiva de um funcionário pra uma ação específica.
bool hasErpPermission({
  required EmployeeRecord employee,
  required PerfilAcessoRecord? perfil,
  required String modulo,
  required String entidade,
  required String acao,
}) {
  final chave = '$modulo.$entidade.$acao';

  for (final override in employee.permissaoOverrides) {
    if (override.permissao.chave == chave) return override.liberado;
  }

  if (perfil == null) return false;
  return perfil.tem(modulo, entidade, acao);
}

/// Uma pessoa só concede uma permissão que ela mesma tem — reaproveita a
/// mesma resolução, então o "teto" nunca precisa ser calculado separado.
bool canGrant({
  required EmployeeRecord granter,
  required PerfilAcessoRecord? granterPerfil,
  required String modulo,
  required String entidade,
  required String acao,
}) {
  return hasErpPermission(
    employee: granter,
    perfil: granterPerfil,
    modulo: modulo,
    entidade: entidade,
    acao: acao,
  );
}

/// `candidateSuperiorId` está na cadeia de avaliador acima de `employeeId`?
/// Usa a lista completa de funcionários da organização pra subir a cadeia.
/// Corta em [maxDepth] pra nunca travar num ciclo de dado corrompido.
bool isInReportingChain({
  required String candidateSuperiorId,
  required String employeeId,
  required Map<String, EmployeeRecord> employeesById,
  int maxDepth = 20,
}) {
  var currentId = employeesById[employeeId]?.avaliadorEmployeeId;
  var depth = 0;
  while (currentId != null && depth < maxDepth) {
    if (currentId == candidateSuperiorId) return true;
    currentId = employeesById[currentId]?.avaliadorEmployeeId;
    depth++;
  }
  return false;
}
