import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmSenhaController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _loading = false;

  String _extractAuthCode(String code, String? message) {
    final trimmedCode = code.trim();
    if (trimmedCode.startsWith('auth/')) {
      return trimmedCode.substring(5);
    }

    final normalizedMessage = (message ?? '').trim();
    final regex = RegExp(r'auth/([a-zA-Z0-9\-]+)');
    final match = regex.firstMatch(normalizedMessage);
    if (match != null) {
      return match.group(1) ?? trimmedCode;
    }

    return trimmedCode;
  }

  String _friendlyAuthError(String code, String? message) {
    final normalizedCode = _extractAuthCode(code, message);
    switch (normalizedCode) {
      case 'email-already-in-use':
        return 'Este email já está em uso. (${message ?? 'auth/email-already-in-use'})';
      case 'invalid-email':
        return 'Email inválido. (${message ?? 'auth/invalid-email'})';
      case 'weak-password':
        return 'Senha fraca. Use ao menos 6 caracteres. (${message ?? 'auth/weak-password'})';
      case 'operation-not-allowed':
        return 'Cadastro por email/senha não habilitado no Firebase Console. (${message ?? 'auth/operation-not-allowed'})';
      case 'unauthorized-domain':
        return 'Domínio não autorizado no Firebase Auth para Web. Adicione o domínio em Authentication > Settings > Authorized domains. (${message ?? 'auth/unauthorized-domain'})';
      case 'network-request-failed':
        return 'Falha de rede. Verifique sua conexão. (${message ?? normalizedCode})';
      case 'invalid-input':
        return 'Preencha nome, email e senha. (${message ?? normalizedCode})';
      default:
        return 'Falha no cadastro [${normalizedCode.isEmpty ? 'sem-código' : normalizedCode}]: ${message ?? 'erro sem detalhes do Firebase'}';
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    _confirmSenhaController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    final nome = _nomeController.text.trim();
    final email = _emailController.text.trim();
    final senha = _senhaController.text;

    if (nome.isEmpty || email.isEmpty || senha.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha todos os campos obrigatórios.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await AuthService.instance.register(
        nome: nome,
        email: email,
        password: senha,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuário cadastrado com sucesso.')),
      );
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      debugPrint('[RegisterScreen] code=${e.code} message=${e.message}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyAuthError(e.code, e.message))),
      );
    } on FirebaseException catch (e) {
      debugPrint('[RegisterScreen] firestore code=${e.code} message=${e.message}');
      if (!mounted) return;

      final isPermissionDenied = e.code.trim().toLowerCase() == 'permission-denied';
      final rawMessage = e.message ?? e.toString();
      final message = isPermissionDenied
          ? 'Cadastro no Auth criado, mas a gravação do usuário na coleção users foi negada pelo Firestore (permission-denied): $rawMessage'
          : 'Falha ao gravar dados do usuário no Firestore [${e.code}]: $rawMessage';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      final raw = e.toString();
      final extractedCode = _extractAuthCode('', raw);
      debugPrint('[RegisterScreen] unexpected error=$raw extractedCode=$extractedCode');
      if (!mounted) return;
      final message = _friendlyAuthError(
        extractedCode,
        raw,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Criar conta')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nomeController,
                      decoration: const InputDecoration(
                        labelText: 'Nome',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Informe o nome'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final value = v?.trim() ?? '';
                        if (value.isEmpty) return 'Informe o email';
                        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
                          return 'Email inválido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _senhaController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Senha',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if ((v ?? '').length < 6) {
                          return 'Senha deve ter ao menos 6 caracteres';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmSenhaController,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _register(),
                      decoration: const InputDecoration(
                        labelText: 'Confirmar senha',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if ((v ?? '').isEmpty) return 'Confirme a senha';
                        if (v != _senhaController.text) return 'As senhas não coincidem';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loading ? null : _register,
                      child: _loading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Cadastrar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

