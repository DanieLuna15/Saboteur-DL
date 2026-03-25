import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthService {
  final fb_auth.FirebaseAuth _auth = fb_auth.FirebaseAuth.instance;
  
  // En la versión 6.2.1, el constructor GoogleSignIn() es público y funciona normalmente
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>['email'],
    // serverClientId no es compatible con Web en esta versión del plugin
    serverClientId: kIsWeb ? null : '949426880918-o7ldm1f3ct87imvrmf2huvaml99olj5u.apps.googleusercontent.com',
  );

  Stream<fb_auth.User?> get userStream => _auth.authStateChanges();

  Future<fb_auth.UserCredential?> signInWithGoogle() async {
    print('Intentando iniciar sesión con Google...');
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print('Inicio de sesión cancelado por el usuario (popup cerrado o atrás).');
        return null; // Retornamos null para cancelación manual
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
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('popup_closed') || 
          errorStr.contains('canceled') || 
          errorStr.contains('user-cancelled')) {
        print('Inicio de sesión cancelado de forma segura: $e');
        return null;
      }
      
      print('ERROR CRÍTICO real en Google Sign-In: $e');
      rethrow;
    }
  }

  Future<fb_auth.UserCredential?> signInAnonymously(String name) async {
    print('Intentando iniciar sesión como invitado con nombre: $name');
    try {
      final result = await _auth.signInAnonymously();
      await result.user?.updateDisplayName(name);
      await result.user?.reload(); // FORZAR RECARGA DEL PERFIL
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
