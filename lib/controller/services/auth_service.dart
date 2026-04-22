import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'mfa_service.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const ['email'],
    serverClientId:
        '668799681896-p0is02rnnbaktjnbgn6tgo0aklfb959c.apps.googleusercontent.com',
  );
  final _mfaService = MFAService.instance;

  Future<User?> signInWithGoogle() async {
    try {
      // Clear previous temporary session so chooser can appear
      await _googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return null; // user cancelled
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      return userCredential.user;
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw Exception('Google sign in failed: $e');
    }
  }

  Future<void> logout() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      // Clear JWT token
      await _mfaService.deleteJWTToken(currentUser.uid);
    }
    await _auth.signOut();

    try {
      await _googleSignIn.disconnect();
    } catch (_) {
      await _googleSignIn.signOut();
    }
  }

  /// Check if user needs MFA verification (returns true if MFA is required)
  Future<bool> requiresMFAVerification(String uid) async {
    return await _mfaService.isMFAEnabled(uid);
  }

  /// Get current authenticated user
  User? getCurrentUser() {
    return _auth.currentUser;
  }
}
