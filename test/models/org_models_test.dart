import 'package:flutter_test/flutter_test.dart';
import 'package:obra_check/models/construtora_record.dart';
import 'package:obra_check/models/project_record.dart';
import 'package:obra_check/models/user_org_membership.dart';

void main() {
  group('ProjectRecord.orgId', () {
    test('toMap/fromMap preserva orgId', () {
      final original = ProjectRecord(
        id: 'p-1',
        name: 'Obra Central',
        code: 'OC01',
        isActive: true,
        createdAt: DateTime(2026, 7, 17),
        updatedAt: DateTime(2026, 7, 17),
        orgId: 'org-1',
      );

      final restored = ProjectRecord.fromMap(original.toMap());

      expect(restored.orgId, 'org-1');
    });

    test('dado legado sem orgId vira string vazia (obra sem construtora)', () {
      final restored = ProjectRecord.fromMap(const {
        'id': 'p-legado',
        'name': 'Obra Antiga',
        'code': 'OA01',
        'isActive': true,
      });

      expect(restored.orgId, '');
    });

    test('construtor sem orgId assume vazio (compatível com código existente)', () {
      final record = ProjectRecord(
        id: 'p-2',
        name: 'Obra Nova',
        code: 'ON01',
        isActive: true,
        createdAt: DateTime(2026, 7, 17),
        updatedAt: DateTime(2026, 7, 17),
      );

      expect(record.orgId, '');
      expect(record.copyWith(orgId: 'org-9').orgId, 'org-9');
    });
  });

  group('ConstrutoraRecord', () {
    test('toMap/fromMap preserva os dados (ida e volta)', () {
      final original = ConstrutoraRecord(
        id: 'org-1',
        name: 'Construtora Alfa',
        isActive: true,
        createdAt: DateTime(2026, 7, 17, 10, 30),
        updatedAt: DateTime(2026, 7, 17, 11, 45),
      );

      final restored = ConstrutoraRecord.fromMap(original.toMap());

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.isActive, original.isActive);
      expect(restored.createdAt, original.createdAt);
      expect(restored.updatedAt, original.updatedAt);
    });

    test('fromMap tolera mapa vazio sem quebrar (dado legado/incompleto)', () {
      final restored = ConstrutoraRecord.fromMap(const {});

      expect(restored.id, '');
      expect(restored.name, '');
      expect(restored.isActive, true);
    });

    test('fromMap respeita isActive=false explícito', () {
      final restored = ConstrutoraRecord.fromMap(const {'isActive': false});

      expect(restored.isActive, false);
    });
  });

  group('UserOrgMembership', () {
    test('toMap/fromMap preserva os dados (ida e volta)', () {
      final original = UserOrgMembership(
        id: 'm-1',
        userId: 'user-9',
        orgId: 'org-1',
        role: UserOrgMembership.roleDiretor,
        isActive: true,
        createdAt: DateTime(2026, 7, 17, 8, 0),
        updatedAt: DateTime(2026, 7, 17, 9, 0),
      );

      final restored = UserOrgMembership.fromMap(original.toMap());

      expect(restored.id, original.id);
      expect(restored.userId, original.userId);
      expect(restored.orgId, original.orgId);
      expect(restored.role, original.role);
      expect(restored.isActive, original.isActive);
      expect(restored.createdAt, original.createdAt);
      expect(restored.updatedAt, original.updatedAt);
    });

    test('fromMap sem role assume diretor (único papel de org hoje)', () {
      final restored = UserOrgMembership.fromMap(const {
        'id': 'm-2',
        'userId': 'user-1',
        'orgId': 'org-2',
      });

      expect(restored.role, UserOrgMembership.roleDiretor);
      expect(UserOrgMembership.isDiretor(restored.role), true);
    });

    test('isDiretor rejeita papéis desconhecidos', () {
      expect(UserOrgMembership.isDiretor('admin'), false);
      expect(UserOrgMembership.isDiretor(''), false);
    });
  });
}
