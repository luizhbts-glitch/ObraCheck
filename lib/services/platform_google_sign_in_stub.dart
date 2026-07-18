class PlatformGoogleSignIn {
  Future<PlatformGoogleUser?> signIn() async => null;

  Future<void> signOut() async {}
}

class PlatformGoogleUser {
  Future<PlatformGoogleAuthTokens> authentication() async {
    return const PlatformGoogleAuthTokens(
      accessToken: null,
      idToken: null,
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

PlatformGoogleSignIn? createPlatformGoogleSignIn() => null;
