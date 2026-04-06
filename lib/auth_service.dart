import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:async';

class AuthService {
  final _auth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with Google - supports Web, iOS, Android, and macOS
  Future<UserCredential> signInWithGoogle() async {
    if (kIsWeb) {
      // Web: popup works
      final provider = GoogleAuthProvider();
      return _auth.signInWithPopup(provider);
    }

    if (Platform.isMacOS) {
      // macOS: Use Firebase's built-in provider sign-in
      final provider = GoogleAuthProvider();
      return _auth.signInWithProvider(provider);
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

  /// Sign in with Apple - supports iOS, macOS
  Future<UserCredential> signInWithApple() async {
    if (!Platform.isIOS && !Platform.isMacOS) {
      throw UnsupportedError('Apple Sign-In is only available on iOS and macOS');
    }

    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [], // Empty scopes for basic authentication
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: credential.identityToken,
        accessToken: credential.authorizationCode,
      );

      return await _auth.signInWithCredential(oauthCredential);
    } on SignInWithAppleAuthorizationException catch (e) {
      throw FirebaseAuthException(
        code: 'apple-sign-in-failed',
        message: 'Apple Sign-In failed: ${e.message}',
      );
    } catch (e) {
      throw FirebaseAuthException(
        code: 'apple-sign-in-error',
        message: 'An error occurred: $e',
      );
    }
  }

  // Alternative authentication methods
  Future<UserCredential> signInAnonymously() => _auth.signInAnonymously();
  
  Future<UserCredential> signInWithEmail(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<void> signOut() => _auth.signOut();
}
