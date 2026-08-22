import 'package:flutter_test/flutter_test.dart';
import 'package:obra_check/utils/permission_catalog.dart';

void main() {
  test('catálogo não tem módulo+entidade+ação duplicado', () {
    expect(findDuplicatePermissionCatalogKeys(), isEmpty);
  });

  test('todo item do catálogo tem pelo menos uma ação', () {
    for (final entry in permissionCatalog) {
      expect(entry.acoes, isNotEmpty, reason: '${entry.modulo}.${entry.entidade} sem ações');
    }
  });

  test('agrupamento por módulo preserva todos os itens', () {
    final grouped = groupPermissionCatalogByModulo();
    final total = grouped.values.fold<int>(0, (sum, list) => sum + list.length);
    expect(total, permissionCatalog.length);
  });
}
