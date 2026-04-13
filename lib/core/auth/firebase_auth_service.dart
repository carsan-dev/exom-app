import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _googleSignInInitialized = false;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> signInWithCustomToken(String token) {
    return _auth.signInWithCustomToken(token);
  }

  Future<UserCredential> signInWithCredential(AuthCredential credential) {
    return _auth.signInWithCredential(credential);
  }

  Future<void> _ensureGoogleSignInInitialized() async {
    if (_googleSignInInitialized) return;

    await _googleSignIn.initialize(
      serverClientId:
          '54623066843-fp0j7vv8mrahve2qsjki9600u13qtbjf.apps.googleusercontent.com',
    );
    _googleSignInInitialized = true;
  }

  Future<OAuthCredential> createGoogleCredential() async {
    await _ensureGoogleSignInInitialized();

    final account = await _googleSignIn.authenticate();

    final googleAuth = account.authentication;
    return GoogleAuthProvider.credential(idToken: googleAuth.idToken);
  }

  Future<UserCredential> signInWithGoogle() async {
    final credential = await createGoogleCredential();
    return signInWithCredential(credential);
  }

  Future<OAuthCredential> createAppleCredential() async {
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    return OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );
  }

  Future<UserCredential> signInWithApple() async {
    final credential = await createAppleCredential();
    return signInWithCredential(credential);
  }

  Future<String?> getIdToken({bool forceRefresh = false}) async {
    return _auth.currentUser?.getIdToken(forceRefresh);
  }

  Future<UserCredential> linkCurrentUserWithCredential(
    AuthCredential credential,
  ) {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No hay ninguna sesión activa para vincular.',
      );
    }

    return user.linkWithCredential(credential);
  }

  Future<void> signOut() async {
    if (!_googleSignInInitialized) {
      await _auth.signOut();
      return;
    }

    await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }
}
