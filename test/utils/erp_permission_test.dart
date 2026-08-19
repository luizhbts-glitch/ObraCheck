import 'package:flutter_test/flutter_test.dart';
import 'package:obra_check/models/employee_record.dart';
import 'package:obra_check/models/perfil_acesso_record.dart';
import 'package:obra_check/utils/erp_permission.dart';

EmployeeRecord _employee({
  required String id,
  String? avaliadorEmployeeId,
  String? perfilAcessoId,
  List<PermissaoOverride>? overrides,
}) {
  return EmployeeRecord(
    id: id,
    orgId: 'org-1',
    cargoId: 'c-1',
    nome: id,
    avaliadorEmployeeId: avaliadorEmployeeId,
    perfilAcessoId: perfilAcessoId,
    permissaoOverrides: overrides,
    createdAt: DateTime(2026, 7, 18),
    updatedAt: DateTime(2026, 7, 18),
  );
}

void main() {
  final perfilComprador = PerfilAcessoRecord(
    id: 'perfil-comprador',
    orgId: 'org-1',
    nome: 'Comprador',
    permissoes: const [
      PermissaoItem(modulo: 'Compras', entidade: 'Requisicao', acao: AcaoPermissao.criar),
      PermissaoItem(modulo: 'Compras', entidade: 'Requisicao', acao: AcaoPermissao.editar),
    ],
    criadoPorEmployeeId: 'e-0',
    createdAt: DateTime(2026, 7, 18),
    updatedAt: DateTime(2026, 7, 18),
  );

  group('hasErpPermission', () {
    test('sem perfil, sem override: nunca tem permissão', () {
      final e = _employee(id: 'e-1');
      final result = hasErpPermission(
        employee: e,
        perfil: null,
        modulo: 'Compras',
        entidade: 'Requisicao',
        acao: AcaoPermissao.criar,
      );
      expect(result, false);
    });

    test('permissão vem do perfil quando não há override', () {
      final e = _employee(id: 'e-1', perfilAcessoId: perfilComprador.id);
      expect(
        hasErpPermission(
          employee: e,
          perfil: perfilComprador,
          modulo: 'Compras',
          entidade: 'Requisicao',
          acao: AcaoPermissao.criar,
        ),
        true,
      );
      expect(
        hasErpPermission(
          employee: e,
          perfil: perfilComprador,
          modulo: 'Compras',
          entidade: 'Requisicao',
          acao: AcaoPermissao.aprovar,
        ),
        false,
      );
    });

    test('override revoga o que o perfil concederia', () {
      final e = _employee(
        id: 'e-1',
        perfilAcessoId: perfilComprador.id,
        overrides: [
          PermissaoOverride(
            permissao: const PermissaoItem(
              modulo: 'Compras',
              entidade: 'Requisicao',
              acao: AcaoPermissao.editar,
            ),
            liberado: false,
            concedidoPorEmployeeId: 'e-0',
            concedidoEm: DateTime(2026, 7, 18),
          ),
        ],
      );

      expect(
        hasErpPermission(
          employee: e,
          perfil: perfilComprador,
          modulo: 'Compras',
          entidade: 'Requisicao',
          acao: AcaoPermissao.editar,
        ),
        false,
      );
      // Não afeta as demais permissões do perfil.
      expect(
        hasErpPermission(
          employee: e,
          perfil: perfilComprador,
          modulo: 'Compras',
          entidade: 'Requisicao',
          acao: AcaoPermissao.criar,
        ),
        true,
      );
    });

    test('override concede algo além do que o perfil dá', () {
      final e = _employee(
        id: 'e-1',
        perfilAcessoId: perfilComprador.id,
        overrides: [
          PermissaoOverride(
            permissao: const PermissaoItem(
              modulo: 'Compras',
              entidade: 'Requisicao',
              acao: AcaoPermissao.aprovar,
            ),
            liberado: true,
            concedidoPorEmployeeId: 'e-0',
            concedidoEm: DateTime(2026, 7, 18),
          ),
        ],
      );

      expect(
        hasErpPermission(
          employee: e,
          perfil: perfilComprador,
          modulo: 'Compras',
          entidade: 'Requisicao',
          acao: AcaoPermissao.aprovar,
        ),
        true,
      );
    });
  });

  group('canGrant — regra do teto', () {
    test('quem não tem a permissão não pode concedê-la a ninguém', () {
      final chefeSemPermissao = _employee(id: 'chefe');
      final result = canGrant(
        granter: chefeSemPermissao,
        granterPerfil: null,
        modulo: 'Diretoria',
        entidade: 'Configuracoes',
        acao: AcaoPermissao.editar,
      );
      expect(result, false);
    });

    test('engenheiro pode conceder ao subalterno até o próprio teto', () {
      final engenheiro = _employee(id: 'eng', perfilAcessoId: perfilComprador.id);
      expect(
        canGrant(
          granter: engenheiro,
          granterPerfil: perfilComprador,
          modulo: 'Compras',
          entidade: 'Requisicao',
          acao: AcaoPermissao.criar,
        ),
        true,
      );
      // Não pode conceder o que ele mesmo não tem (ex.: aprovar despesa de Diretoria).
      expect(
        canGrant(
          granter: engenheiro,
          granterPerfil: perfilComprador,
          modulo: 'Diretoria',
          entidade: 'Configuracoes',
          acao: AcaoPermissao.editar,
        ),
        false,
      );
    });
  });

  group('isInReportingChain', () {
    test('sobe a cadeia de avaliador corretamente', () {
      final diretor = _employee(id: 'diretor');
      final coordenador = _employee(id: 'coord', avaliadorEmployeeId: 'diretor');
      final engenheiro = _employee(id: 'eng', avaliadorEmployeeId: 'coord');
      final auxiliar = _employee(id: 'aux', avaliadorEmployeeId: 'eng');

      final byId = {
        for (final e in [diretor, coordenador, engenheiro, auxiliar]) e.id: e,
      };

      expect(
        isInReportingChain(
          candidateSuperiorId: 'diretor',
          employeeId: 'aux',
          employeesById: byId,
        ),
        true,
      );
      expect(
        isInReportingChain(
          candidateSuperiorId: 'eng',
          employeeId: 'aux',
          employeesById: byId,
        ),
        true,
      );
      expect(
        isInReportingChain(
          candidateSuperiorId: 'aux',
          employeeId: 'diretor',
          employeesById: byId,
        ),
        false,
      );
    });

    test('não trava em ciclo de dado corrompido', () {
      final a = _employee(id: 'a', avaliadorEmployeeId: 'b');
      final b = _employee(id: 'b', avaliadorEmployeeId: 'a');
      final byId = {'a': a, 'b': b};

      expect(
        () => isInReportingChain(
          candidateSuperiorId: 'nao-existe',
          employeeId: 'a',
          employeesById: byId,
        ),
        returnsNormally,
      );
    });
  });
}
