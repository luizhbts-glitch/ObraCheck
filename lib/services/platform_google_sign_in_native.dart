import 'package:google_sign_in/google_sign_in.dart';

class PlatformGoogleSignIn {
  PlatformGoogleSignIn() : _delegate = GoogleSignIn();

  final GoogleSignIn _delegate;

  Future<PlatformGoogleUser?> signIn() async {
    final user = await _delegate.signIn();
    if (user == null) return null;
    return PlatformGoogleUser(user);
  }

  Future<void> signOut() => _delegate.signOut();
}

class PlatformGoogleUser {
  PlatformGoogleUser(this._delegate);

  final GoogleSignInAccount _delegate;

  Future<PlatformGoogleAuthTokens> authentication() async {
    final auth = await _delegate.authentication;
    return PlatformGoogleAuthTokens(
      accessToken: auth.accessToken,
      idToken: auth.idToken,
    );
  }
}

class PlatformGoogleAuthTokens {
  const PlatformGoogleAuthTokens({
    required this.accessToken,
    required this.idToken,
  });

  final String? accessToken;
  final String? idToken;
}

PlatformGoogleSignIn? createPlatformGoogleSignIn() => PlatformGoogleSignIn();
