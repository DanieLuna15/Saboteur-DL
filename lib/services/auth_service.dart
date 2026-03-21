import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final fb_auth.FirebaseAuth _auth = fb_auth.FirebaseAuth.instance;
  
  // En la versión 6.2.1, el constructor GoogleSignIn() es público y funciona normalmente
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>['email'],
  );

  Stream<fb_auth.User?> get userStream => _auth.authStateChanges();

  Future<fb_auth.UserCredential?> signInWithGoogle() async {
    print('Intentando iniciar sesión con Google...');
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print('Inocio de sesión cancelado por el usuario.');
        return null;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final fb_auth.AuthCredential credential = fb_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final result = await _auth.signInWithCredential(credential);
      print('Inicio de sesión exitoso: ${result.user?.uid}');
      return result;
    } catch (e) {
      print('ERROR CRÍTICO en Google Sign-In: $e');
      return null;
    }
  }

  Future<fb_auth.UserCredential?> signInAnonymously() async {
    print('Intentando iniciar sesión como invitado...');
    try {
      final result = await _auth.signInAnonymously();
      print('Inicio de sesión anónimo exitoso: ${result.user?.uid}');
      return result;
    } catch (e) {
      print('ERROR CRÍTICO en Inicio Anónimo: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _auth.signOut();
  }
}
