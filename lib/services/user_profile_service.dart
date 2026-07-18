import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'auth_service.dart';

class UserProfileData {
  final String uid;
  final String nome;
  final String cargo;
  final String? email;
  final String? company;

  const UserProfileData({
    required this.uid,
    required this.nome,
    required this.cargo,
    this.email,
    this.company,
  });
}

class _ObraScope {
  final String field;
  final String value;

  const _ObraScope({
    required this.field,
    required this.value,
  });
}

class UserProfileService {
  UserProfileService._();

  static final UserProfileService instance = UserProfileService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<UserProfileData?> getCurrentUserProfile() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final data = doc.data();
      if (data == null) {
        return UserProfileData(
          uid: user.uid,
          nome: '',
          cargo: '',
          email: user.email,
          company: null,
        );
      }

      return UserProfileData(
        uid: user.uid,
        nome: (data['nome']?.toString().trim().isNotEmpty == true)
            ? data['nome'].toString().trim()
            : '',
        cargo: data['cargo']?.toString().trim() ?? '',
        email: data['email']?.toString().trim().isNotEmpty == true
            ? data['email'].toString().trim()
            : user.email,
        company: data['company']?.toString().trim(),
      );
    } catch (e) {
      debugPrint('[UserProfileService] erro ao carregar perfil: $e');
        return UserProfileData(
          uid: user.uid,
          nome: '',
          cargo: '',
          email: user.email,
          company: null,
        );
    }
  }

  Future<void> saveCurrentUserName(String nome) async {
    await saveCurrentUserProfile(nome: nome, cargo: null);
  }

  Future<void> saveCurrentUserProfile({
    required String nome,
    String? cargo,
  }) async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;

    final trimmedName = nome.trim();
    final trimmedCargo = cargo?.trim();
    if (trimmedName.isEmpty) return;
    if (cargo != null && (trimmedCargo == null || trimmedCargo.isEmpty)) return;

    final payload = <String, dynamic>{
      'nome': trimmedName,
      'nomeLower': trimmedName.toLowerCase(),
    };

    if (trimmedCargo != null) {
      payload['cargo'] = trimmedCargo;
    }

    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(payload, SetOptions(merge: true));
  }

  Future<List<UserProfileData>> getOtherUsersFromSameObra() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return const [];

    try {
      final currentDoc = await _firestore.collection('users').doc(user.uid).get();
      final currentData = currentDoc.data();
      if (currentData == null) return const [];

      final scope = _extractObraScope(currentData);
      if (scope == null) return const [];

      final snap = await _firestore
          .collection('users')
          .where(scope.field, isEqualTo: scope.value)
          .get();

      final users = snap.docs
          .where((doc) => doc.id != user.uid)
          .map((doc) {
            final data = doc.data();
            final email = data['email']?.toString().trim();
            final nome = data['nome']?.toString().trim();

            return UserProfileData(
              uid: doc.id,
              nome: (nome != null && nome.isNotEmpty)
                  ? nome
                  : (email != null && email.contains('@'))
                      ? email.split('@').first
                      : 'Usuário sem nome',
              cargo: data['cargo']?.toString().trim() ?? '',
              email: (email != null && email.isNotEmpty) ? email : null,
            );
          })
          .toList()
        ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));

      return users;
    } catch (e) {
      debugPrint('[UserProfileService] erro ao carregar usuários da obra: $e');
      return const [];
    }
  }

  _ObraScope? _extractObraScope(Map<String, dynamic> data) {
    const possibleFields = [
      'obraCode',
      'obra_code',
      'obraId',
      'obra',
      'obraNome',
    ];

    for (final field in possibleFields) {
      final value = data[field]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return _ObraScope(field: field, value: value);
      }
    }

    return null;
  }
}

