import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// Verifica se o usuário logado é administrador global do produto.
///
/// A fonte de verdade é o Firestore (`global_admins/{uid}`), cadastrado
/// manualmente — não existe fluxo no app para promover alguém. O resultado
/// fica cacheado em `prefs` para o app offline-first não depender de rede
/// a cada checagem (e nunca conceder o papel sem confirmação prévia).
class GlobalAdminService {
  GlobalAdminService._();

  static final GlobalAdminService instance = GlobalAdminService._();

  static const String _prefsKeyPrefix = 'is_global_admin_';

  bool _checkedThisSession = false;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Box get _prefs => Hive.box('prefs');

  /// Leitura síncrona do cache — segura pra usar em build de UI.
  /// Sem cache (primeiro uso, offline) assume que NÃO é admin global.
  bool get isGlobalAdminSync {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return false;
    return isGlobalAdminSyncFor(uid);
  }

  /// Variante por uid, sem tocar FirebaseAuth — usada pelo
  /// ProjectContextService, que já mantém o uid da sessão.
  bool isGlobalAdminSyncFor(String uid) {
    if (uid.trim().isEmpty) return false;
    if (!Hive.isBoxOpen('prefs')) return false;
    return _prefs.get('$_prefsKeyPrefix${uid.trim()}', defaultValue: false) ==
        true;
  }

  /// Consulta o Firestore e atualiza o cache. Chamar após login e no
  /// início de sessão com internet; falha de rede mantém o cache atual.
  Future<bool> refresh() async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return false;

    try {
      // Timeout explícito: sem ele, uma cota do Firestore esgotada deixava
      // essa chamada pendurada indefinidamente — como isso roda logo no
      // início de toda hidratação de sessão, travava login e validação de
      // código de acesso junto.
      final doc = await FirebaseFirestore.instance
          .collection('global_admins')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 10));
      final isAdmin = doc.exists && doc.data()?['isActive'] != false;
      await _prefs.put('$_prefsKeyPrefix$uid', isAdmin);
      _checkedThisSession = true;
      return isAdmin;
    } catch (e) {
      debugPrint('[GLOBAL_ADMIN] Falha ao consultar status (mantendo cache): $e');
      return isGlobalAdminSync;
    }
  }

  Future<bool> ensureChecked() async {
    if (_checkedThisSession) return isGlobalAdminSync;
    return refresh();
  }
}
