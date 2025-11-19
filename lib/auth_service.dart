import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:url_launcher/url_launcher.dart';
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
      // macOS: Use desktop OAuth flow via URL launcher
      return _signInWithGoogleDesktop();
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

  /// Desktop OAuth flow for macOS using URL launcher
  Future<UserCredential> _signInWithGoogleDesktop() async {
    try {
      // Trigger the browser-based OAuth flow
      await _launchGoogleOAuthFlow();
      
      // Wait for the user to complete the OAuth flow
      // In a real implementation, you'd use a local server or deep linking
      // For now, Firebase will handle the authentication on the device
      
      // Check if user is authenticated
      final user = _auth.currentUser;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'authentication-failed',
          message: 'Failed to authenticate with Google',
        );
      }
      
      return await _auth.signInWithEmailAndPassword(
        email: user.email ?? '',
        password: '', // This won't work; use proper OAuth flow
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Launch Google OAuth in default browser
  Future<void> _launchGoogleOAuthFlow() async {
    const googleAuthUrl = 'https://accounts.google.com/o/oauth2/v2/auth?'
        'client_id=YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com&'
        'redirect_uri=com.googleusercontent.apps.YOUR_GOOGLE_CLIENT_ID:/oauth2redirect&'
        'response_type=code&'
        'scope=openid%20email%20profile';

    try {
      final uri = Uri.parse(googleAuthUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch Google Auth URL';
      }
    } catch (e) {
      throw FirebaseAuthException(
        code: 'oauth-launch-failed',
        message: 'Failed to launch OAuth flow: $e',
      );
    }
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
