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

  Future<void> _ensureGoogleSignInInitialized() async {
    if (_googleSignInInitialized) return;

    await _googleSignIn.initialize(
      serverClientId:
          '54623066843-fp0j7vv8mrahve2qsjki9600u13qtbjf.apps.googleusercontent.com',
    );
    _googleSignInInitialized = true;
  }

  Future<UserCredential> signInWithGoogle() async {
    await _ensureGoogleSignInInitialized();

    final account = await _googleSignIn.authenticate();

    final googleAuth = account.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );
    return _auth.signInWithCredential(credential);
  }

  Future<UserCredential> signInWithApple() async {
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );

    return _auth.signInWithCredential(oauthCredential);
  }

  Future<String?> getIdToken({bool forceRefresh = false}) async {
    return _auth.currentUser?.getIdToken(forceRefresh);
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
