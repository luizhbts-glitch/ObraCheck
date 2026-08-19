import 'package:flutter_test/flutter_test.dart';
import 'package:obra_check/models/cargo_record.dart';
import 'package:obra_check/models/employee_record.dart';
import 'package:obra_check/models/perfil_acesso_record.dart';

void main() {
  group('CargoRecord', () {
    test('toMap/fromMap preserva os dados', () {
      final original = CargoRecord(
        id: 'c-1',
        orgId: 'org-1',
        nome: 'Engenheiro',
        nivelHierarquico: 4,
        perfilAcessoIdPadrao: 'perfil-1',
        createdAt: DateTime(2026, 7, 18),
        updatedAt: DateTime(2026, 7, 18),
      );

      final restored = CargoRecord.fromMap(original.toMap());

      expect(restored.nome, 'Engenheiro');
      expect(restored.nivelHierarquico, 4);
      expect(restored.perfilAcessoIdPadrao, 'perfil-1');
      expect(restored.isActive, true);
    });

    test('nivelHierarquico ausente cai pra 6 (mais baixo, seguro)', () {
      final restored = CargoRecord.fromMap(const {'id': 'c-2', 'nome': 'X'});
      expect(restored.nivelHierarquico, 6);
    });
  });

  group('EmployeeRecord', () {
    test('toMap/fromMap preserva os dados, incluindo overrides', () {
      final original = EmployeeRecord(
        id: 'e-1',
        orgId: 'org-1',
        projectId: 'obra-1',
        cargoId: 'c-1',
        nome: 'Luiz',
        avaliadorEmployeeId: 'e-0',
        userId: 'uid-1',
        perfilAcessoId: 'perfil-1',
        permissaoOverrides: [
          PermissaoOverride(
            permissao: const PermissaoItem(
              modulo: 'Compras',
              entidade: 'Requisicao',
              acao: AcaoPermissao.aprovar,
            ),
            liberado: false,
            concedidoPorEmployeeId: 'e-0',
            concedidoEm: DateTime(2026, 7, 18),
          ),
        ],
        createdAt: DateTime(2026, 7, 18),
        updatedAt: DateTime(2026, 7, 18),
      );

      final restored = EmployeeRecord.fromMap(original.toMap());

      expect(restored.nome, 'Luiz');
      expect(restored.avaliadorEmployeeId, 'e-0');
      expect(restored.userId, 'uid-1');
      expect(restored.permissaoOverrides, hasLength(1));
      expect(restored.permissaoOverrides.first.liberado, false);
      expect(
        restored.permissaoOverrides.first.permissao.chave,
        'Compras.Requisicao.aprovar',
      );
    });

    test('funcionário sem conta no app: userId e avaliador ficam nulos', () {
      final restored = EmployeeRecord.fromMap(const {
        'id': 'e-2',
        'orgId': 'org-1',
        'cargoId': 'c-2',
        'nome': 'Servente sem login',
      });

      expect(restored.userId, isNull);
      expect(restored.avaliadorEmployeeId, isNull);
      expect(restored.projectId, '');
    });
  });

  group('PerfilAcessoRecord', () {
    test('tem() encontra permissão cadastrada', () {
      final perfil = PerfilAcessoRecord(
        id: 'p-1',
        orgId: 'org-1',
        nome: 'Comprador',
        permissoes: const [
          PermissaoItem(
            modulo: 'Compras',
            entidade: 'Requisicao',
            acao: AcaoPermissao.criar,
          ),
        ],
        criadoPorEmployeeId: 'e-0',
        createdAt: DateTime(2026, 7, 18),
        updatedAt: DateTime(2026, 7, 18),
      );

      expect(perfil.tem('Compras', 'Requisicao', AcaoPermissao.criar), true);
      expect(perfil.tem('Compras', 'Requisicao', AcaoPermissao.aprovar), false);
      expect(perfil.tem('Financeiro', 'Pagamento', AcaoPermissao.aprovar), false);
    });

    test('deduplica permissão repetida na construção — lição do L7', () {
      final perfil = PerfilAcessoRecord(
        id: 'p-2',
        orgId: 'org-1',
        nome: 'Coordenador de Obras',
        permissoes: const [
          PermissaoItem(modulo: 'Obra', entidade: 'Diario', acao: AcaoPermissao.editar),
          PermissaoItem(modulo: 'Obra', entidade: 'Diario', acao: AcaoPermissao.editar),
          PermissaoItem(modulo: 'Obra', entidade: 'Diario', acao: AcaoPermissao.editar),
        ],
        criadoPorEmployeeId: 'e-0',
        createdAt: DateTime(2026, 7, 18),
        updatedAt: DateTime(2026, 7, 18),
      );

      expect(perfil.permissoes, hasLength(1));
    });

    test('toMap/fromMap preserva a lista de permissões', () {
      final original = PerfilAcessoRecord(
        id: 'p-3',
        orgId: 'org-1',
        nome: 'Financeiro',
        permissoes: const [
          PermissaoItem(modulo: 'Financeiro', entidade: 'Pagamento', acao: AcaoPermissao.aprovar),
          PermissaoItem(modulo: 'Compras', entidade: 'Fornecedor', acao: AcaoPermissao.visualizar),
        ],
        criadoPorEmployeeId: 'e-0',
        createdAt: DateTime(2026, 7, 18),
        updatedAt: DateTime(2026, 7, 18),
      );

      final restored = PerfilAcessoRecord.fromMap(original.toMap());

      expect(restored.permissoes, hasLength(2));
      expect(restored.tem('Financeiro', 'Pagamento', AcaoPermissao.aprovar), true);
      expect(restored.tem('Compras', 'Fornecedor', AcaoPermissao.visualizar), true);
    });
  });
}
