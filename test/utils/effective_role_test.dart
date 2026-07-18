import 'package:flutter_test/flutter_test.dart';
import 'package:obra_check/models/user_project_membership.dart';
import 'package:obra_check/utils/effective_role.dart';

void main() {
  group('resolveEffectiveRole — sem elevação', () {
    test('papel direto vale como sempre valeu', () {
      for (final role in [
        UserProjectMembership.roleAdmin,
        UserProjectMembership.roleManager,
        UserProjectMembership.roleInspector,
        UserProjectMembership.roleViewer,
      ]) {
        expect(
          resolveEffectiveRole(
            directRole: role,
            isGlobalAdmin: false,
            isDiretorOfOwningOrg: false,
            editModeEnabled: false,
          ),
          role,
        );
      }
    });

    test('sem vínculo direto vira viewer', () {
      expect(
        resolveEffectiveRole(
          directRole: '',
          isGlobalAdmin: false,
          isDiretorOfOwningOrg: false,
          editModeEnabled: false,
        ),
        UserProjectMembership.roleViewer,
      );
    });

    test('papel desconhecido normaliza pra viewer', () {
      expect(
        resolveEffectiveRole(
          directRole: 'super_hacker',
          isGlobalAdmin: false,
          isDiretorOfOwningOrg: false,
          editModeEnabled: false,
        ),
        UserProjectMembership.roleViewer,
      );
    });

    test('toggle de edição ligado não eleva quem não tem elevação', () {
      expect(
        resolveEffectiveRole(
          directRole: UserProjectMembership.roleInspector,
          isGlobalAdmin: false,
          isDiretorOfOwningOrg: false,
          editModeEnabled: true,
        ),
        UserProjectMembership.roleInspector,
      );
    });
  });

  group('resolveEffectiveRole — diretoria (modo visualização, padrão)', () {
    test('diretor sem vínculo direto enxerga como viewer', () {
      expect(
        resolveEffectiveRole(
          directRole: '',
          isGlobalAdmin: false,
          isDiretorOfOwningOrg: true,
          editModeEnabled: false,
        ),
        UserProjectMembership.roleViewer,
      );
    });

    test('elevação nunca rebaixa papel direto mais forte', () {
      expect(
        resolveEffectiveRole(
          directRole: UserProjectMembership.roleInspector,
          isGlobalAdmin: false,
          isDiretorOfOwningOrg: true,
          editModeEnabled: false,
        ),
        UserProjectMembership.roleInspector,
      );
    });
  });

  group('resolveEffectiveRole — modo edição ligado', () {
    test('diretor vira admin da obra', () {
      expect(
        resolveEffectiveRole(
          directRole: '',
          isGlobalAdmin: false,
          isDiretorOfOwningOrg: true,
          editModeEnabled: true,
        ),
        UserProjectMembership.roleAdmin,
      );
    });

    test('admin global vira admin da obra', () {
      expect(
        resolveEffectiveRole(
          directRole: '',
          isGlobalAdmin: true,
          isDiretorOfOwningOrg: false,
          editModeEnabled: true,
        ),
        UserProjectMembership.roleAdmin,
      );
    });
  });

  group('resolveEffectiveRole — admin global em modo visualização', () {
    test('enxerga como viewer por padrão (mesma regra da diretoria)', () {
      expect(
        resolveEffectiveRole(
          directRole: '',
          isGlobalAdmin: true,
          isDiretorOfOwningOrg: false,
          editModeEnabled: false,
        ),
        UserProjectMembership.roleViewer,
      );
    });
  });

  group('roleStrength', () {
    test('ordena admin > manager > inspector > viewer', () {
      expect(
        roleStrength(UserProjectMembership.roleAdmin) >
            roleStrength(UserProjectMembership.roleManager),
        true,
      );
      expect(
        roleStrength(UserProjectMembership.roleManager) >
            roleStrength(UserProjectMembership.roleInspector),
        true,
      );
      expect(
        roleStrength(UserProjectMembership.roleInspector) >
            roleStrength(UserProjectMembership.roleViewer),
        true,
      );
    });

    test('papel desconhecido tem força de viewer', () {
      expect(roleStrength('qualquer_coisa'),
          roleStrength(UserProjectMembership.roleViewer));
    });
  });
}
