import '../models/user_project_membership.dart';

/// Resolução do papel efetivo do usuário numa obra, considerando a
/// hierarquia: admin global > diretoria da construtora dona da obra >
/// papel direto na obra (engenheiro/administrativo/visualizante).
///
/// Regras decididas em 2026-07-17:
/// - Elevação (admin global ou diretor da construtora dona) dá poder de
///   admin da obra, MAS entra por padrão em modo visualização; só vira
///   admin com o toggle de edição ligado na sessão.
/// - Em modo visualização, o elevado mantém o papel direto que já tiver
///   na obra (se for mais forte que viewer) — a elevação nunca rebaixa.
/// - Sem elevação, o papel direto vale como sempre valeu (viewer se não
///   houver vínculo).

const Map<String, int> _roleStrength = {
  UserProjectMembership.roleViewer: 0,
  UserProjectMembership.roleInspector: 1,
  UserProjectMembership.roleManager: 2,
  UserProjectMembership.roleAdmin: 3,
};

int roleStrength(String role) => _roleStrength[role] ?? 0;

String resolveEffectiveRole({
  required String directRole,
  required bool isGlobalAdmin,
  required bool isDiretorOfOwningOrg,
  required bool editModeEnabled,
}) {
  final normalizedDirect = _roleStrength.containsKey(directRole)
      ? directRole
      : UserProjectMembership.roleViewer;

  final elevated = isGlobalAdmin || isDiretorOfOwningOrg;
  if (!elevated) return normalizedDirect;

  if (editModeEnabled) return UserProjectMembership.roleAdmin;

  // Modo visualização: garante ao menos viewer, sem rebaixar papel direto.
  return normalizedDirect;
}
