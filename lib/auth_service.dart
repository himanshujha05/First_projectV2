import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signInWithGoogle() async {
    if (kIsWeb) {
      // Web: popup works
      final provider = GoogleAuthProvider();
      return _auth.signInWithPopup(provider);
    }

    if (Platform.isMacOS) {
      // macOS: this mobile flow is not supported
      throw UnsupportedError(
        'Google Sign-In is not supported on macOS with this flow. '
        'Use email/password, anonymous, or implement a desktop OAuth flow.',
      );
    }

    if (Platform.isIOS || Platform.isAndroid) {
      // Mobile native flow
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        throw FirebaseAuthException(
          code: 'aborted-by-user',
          message: 'Sign-in aborted by user',
        );
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      return _auth.signInWithCredential(credential);
    }

    throw UnsupportedError('Unsupported platform for Google Sign-In.');
  }

  // Handy alternates for macOS/dev:
  Future<UserCredential> signInAnonymously() => _auth.signInAnonymously();
  Future<UserCredential> signInWithEmail(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<void> signOut() => _auth.signOut();
}
