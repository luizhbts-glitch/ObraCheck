// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'platform_google_sign_in_stub.dart'
    if (dart.library.io) 'platform_google_sign_in_native.dart';

import 'project_members_service.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  PlatformGoogleSignIn? _googleSignIn;

  PlatformGoogleSignIn? get _googleSignInInstance {
    _googleSignIn ??= createPlatformGoogleSignIn();
    return _googleSignIn;
  }

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  bool get isAnonymousSession => _auth.currentUser?.isAnonymous == true;

  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim();
    final rawPassword = password;

    if (normalizedEmail.isEmpty || rawPassword.isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-credentials',
        message: 'Email e senha são obrigatórios.',
      );
    }

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: rawPassword,
      );
      await _ensureUserDocHasEmail(credential.user);
      return credential;
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthService.login] code=${e.code} message=${e.message}');
      rethrow;
    }
  }

  /// Login simples nunca gravava `users/{uid}.email` (só cadastro novo e
  /// login com Google faziam isso) — contas antigas que sempre entraram
  /// por email/senha podem ter esse campo ausente, quebrando qualquer
  /// busca por email (convite pendente, "adicionar diretor" etc.).
  /// Autocorrige em todo login, sem sobrescrever o resto do documento.
  Future<void> _ensureUserDocHasEmail(User? user) async {
    if (user == null) return;
    final email = (user.email ?? '').trim();
    if (email.isEmpty) return;
    try {
      await _firestore.collection('users').doc(user.uid).set(
        {'uid': user.uid, 'email': email},
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('[AuthService._ensureUserDocHasEmail] falhou: $e');
    }
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-email',
        message: 'Informe um email válido para recuperar a senha.',
      );
    }

    try {
      await _auth.sendPasswordResetEmail(email: normalizedEmail);
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthService.sendPasswordResetEmail] code=${e.code} message=${e.message}');
      rethrow;
    }
  }

  Future<UserCredential> loginAnonymously() async {
    try {
      return await _auth.signInAnonymously();
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthService.loginAnonymously] code=${e.code} message=${e.message}');
      rethrow;
    }
  }

  Future<void> ensureAnonymousSession() async {
    if (_auth.currentUser != null) return;
    await loginAnonymously();
  }

  Future<UserCredential> register({
    required String nome,
    required String email,
    required String password,
  }) async {
    const diag = '[REGISTER]';
    final normalizedNome = nome.trim();
    final normalizedEmail = email.trim();
    final rawPassword = password;

    if (normalizedNome.isEmpty || normalizedEmail.isEmpty || rawPassword.isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-input',
        message: 'Nome, email e senha são obrigatórios.',
      );
    }

    print('$diag [AUTH][START] projectId=${_auth.app.options.projectId} email=$normalizedEmail');

    UserCredential credential;
    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: rawPassword,
      );
    } on FirebaseAuthException catch (e) {
      print('$diag [AUTH][FAIL] code=${e.code} message=${e.message}');
      rethrow;
    }

    final user = credential.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-null',
        message: 'Falha ao criar usuário.',
      );
    }

    print('$diag [AUTH][SUCCESS] uid=${user.uid} email=${user.email ?? normalizedEmail}');

    final userPayload = {
      'uid': user.uid,
      'nome': normalizedNome,
      'email': normalizedEmail,
      'createdAt': FieldValue.serverTimestamp(),
    };

    final projectId = _auth.app.options.projectId;
    final uid = user.uid;
    final documentPath = 'users/$uid';

    print('$diag [FIRESTORE][START] projectId=$projectId uid=$uid path=$documentPath payload=$userPayload');

    try {
      await _firestore.collection('users').doc(uid).set(userPayload);
      print('$diag [FIRESTORE][SUCCESS] projectId=$projectId uid=$uid path=$documentPath');
    } on FirebaseException catch (e) {
      print(
        '$diag [FIRESTORE][FAIL] '
        'projectId=$projectId uid=$uid path=$documentPath payload=$userPayload '
        'code=${e.code} message=${e.message}',
      );
      throw Exception(
        'Cadastro criado no Auth, mas falhou ao salvar no Firestore '
        '[projectId=$projectId path=$documentPath code=${e.code} message=${e.message}]',
      );
    }

    return credential;
  }

  Future<UserCredential> loginWithGoogle() async {
    try {
      late UserCredential credential;

      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        credential = await _auth.signInWithPopup(provider);
      } else {
        final googleSignIn = _googleSignInInstance;
        if (googleSignIn == null) {
          throw FirebaseAuthException(
            code: 'google-sign-in-unavailable',
            message: 'Google Sign-In nativo indisponível nesta plataforma.',
          );
        }

        final googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          throw FirebaseAuthException(
            code: 'aborted-by-user',
            message: 'Login com Google cancelado.',
          );
        }

        final googleAuth = await googleUser.authentication();
        final authCredential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        credential = await _auth.signInWithCredential(authCredential);
      }

      final user = credential.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-null',
          message: 'Falha ao autenticar com Google.',
        );
      }

      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'nome': (user.displayName ?? '').trim(),
        'nomeLower': (user.displayName ?? '').trim().toLowerCase(),
        'email': (user.email ?? '').trim(),
        'updatedAt': FieldValue.serverTimestamp(),
        'provider': 'google',
      }, SetOptions(merge: true));

      final email = (user.email ?? '').trim();
      if (email.isNotEmpty) {
        await ProjectMembersService.instance.applyPendingInvitesForEmail(
          userId: user.uid,
          email: email,
        );
      }

      return credential;
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw FirebaseAuthException(
        code: 'google-sign-in-failed',
        message: e.toString(),
      );
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    final googleSignIn = _googleSignIn;
    if (googleSignIn != null) {
      await googleSignIn.signOut();
    }
  }
}

