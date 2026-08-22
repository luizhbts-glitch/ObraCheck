import '../models/perfil_acesso_record.dart';

/// Um item do catálogo: módulo + entidade + as ações que fazem sentido
/// pra ela (nem toda entidade tem as 6 ações — "aprovar" não faz sentido
/// pra um cadastro de equipamento, por exemplo).
class PermissionCatalogEntry {
  const PermissionCatalogEntry({
    required this.modulo,
    required this.entidade,
    required this.acoes,
  });

  final String modulo;
  final String entidade;
  final List<String> acoes;
}

/// Catálogo do que existe hoje no app pra controlar por permissão granular.
/// Cresce junto com o ERP — só lista módulo/entidade que já tem tela de
/// verdade por trás, senão vira permissão fantasma que não controla nada.
const List<PermissionCatalogEntry> permissionCatalog = [
  PermissionCatalogEntry(
    modulo: 'Compras',
    entidade: 'Requisição',
    acoes: [AcaoPermissao.criar, AcaoPermissao.editar, AcaoPermissao.excluir, AcaoPermissao.visualizar],
  ),
  PermissionCatalogEntry(
    modulo: 'Compras',
    entidade: 'Cotação',
    acoes: [AcaoPermissao.criar, AcaoPermissao.editar, AcaoPermissao.aprovar, AcaoPermissao.visualizar],
  ),
  PermissionCatalogEntry(
    modulo: 'Compras',
    entidade: 'Pedido de compra',
    acoes: [AcaoPermissao.criar, AcaoPermissao.editar, AcaoPermissao.aprovar, AcaoPermissao.visualizar],
  ),
  PermissionCatalogEntry(
    modulo: 'Compras',
    entidade: 'Fornecedor',
    acoes: [AcaoPermissao.criar, AcaoPermissao.editar, AcaoPermissao.excluir, AcaoPermissao.visualizar],
  ),
  PermissionCatalogEntry(
    modulo: 'Despesas',
    entidade: 'Despesa',
    acoes: [AcaoPermissao.criar, AcaoPermissao.editar, AcaoPermissao.aprovar, AcaoPermissao.visualizar],
  ),
  PermissionCatalogEntry(
    modulo: 'RH',
    entidade: 'Funcionário',
    acoes: [AcaoPermissao.criar, AcaoPermissao.editar, AcaoPermissao.excluir, AcaoPermissao.visualizar],
  ),
  PermissionCatalogEntry(
    modulo: 'RH',
    entidade: 'Cargo',
    acoes: [AcaoPermissao.criar, AcaoPermissao.editar, AcaoPermissao.visualizar],
  ),
  PermissionCatalogEntry(
    modulo: 'Almoxarifado',
    entidade: 'Equipamento',
    acoes: [AcaoPermissao.criar, AcaoPermissao.editar, AcaoPermissao.excluir, AcaoPermissao.visualizar],
  ),
  PermissionCatalogEntry(
    modulo: 'Almoxarifado',
    entidade: 'Insumo',
    acoes: [AcaoPermissao.criar, AcaoPermissao.editar, AcaoPermissao.excluir, AcaoPermissao.visualizar],
  ),
];

/// Agrupa o catálogo por módulo, na ordem em que aparecem — usado pra
/// montar a tela em seções (uma por módulo).
Map<String, List<PermissionCatalogEntry>> groupPermissionCatalogByModulo() {
  final map = <String, List<PermissionCatalogEntry>>{};
  for (final entry in permissionCatalog) {
    map.putIfAbsent(entry.modulo, () => []).add(entry);
  }
  return map;
}

/// Detecta módulo+entidade+ação duplicados no catálogo — o mesmo cuidado
/// que já existe em `PerfilAcessoRecord._dedupe`, aplicado aqui em cima
/// dos dados estáticos pra pegar erro de cadastro no catálogo em teste,
/// não em produção.
List<String> findDuplicatePermissionCatalogKeys() {
  final seen = <String>{};
  final duplicates = <String>[];
  for (final entry in permissionCatalog) {
    for (final acao in entry.acoes) {
      final chave = '${entry.modulo}.${entry.entidade}.$acao';
      if (!seen.add(chave)) duplicates.add(chave);
    }
  }
  return duplicates;
}

/// Rótulo em português pra cada ação — usado nos chips da tela de
/// permissões.
String acaoLabel(String acao) {
  switch (acao) {
    case AcaoPermissao.criar:
      return 'Criar';
    case AcaoPermissao.editar:
      return 'Editar';
    case AcaoPermissao.excluir:
      return 'Excluir';
    case AcaoPermissao.aprovar:
      return 'Aprovar';
    case AcaoPermissao.rejeitar:
      return 'Rejeitar';
    case AcaoPermissao.visualizar:
      return 'Visualizar';
    default:
      return acao;
  }
}
