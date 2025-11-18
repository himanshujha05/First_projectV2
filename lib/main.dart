import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'auth_service.dart';

import 'calorie_tracker_provider.dart';
import 'profile_info_page.dart'; // Profile setup & macro recommendations

import 'login_page.dart';
import 'home_page.dart';

/// ------------------ Firebase initialization helper ------------------ ///
Future<void> _initFirebase() async {
  // Avoid re-initializing during hot reload
  if (Firebase.apps.isNotEmpty) return;

  // Web must always pass options
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.web,
    );
    return;
  }

  // macOS special-case (in case macOS config is missing from firebase_options)
  if (Platform.isMacOS) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (_) {
      // Fallback: uses macos/Runner/GoogleService-Info.plist
      await Firebase.initializeApp();
    }
    return;
  }

  // Android / iOS / Windows / Linux – normal path
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

/// ------------------------------ main() ------------------------------ ///
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initFirebase();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CalorieTrackerProvider()),
        // ⬆️ Add more providers here later if you create them
      ],
      child: const MyApp(),
    ),
  );
}

/// ------------------------------ MyApp ------------------------------- ///
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CalTrack',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF4CAF50),
        brightness: Brightness.dark,
      ),

      // Optional named routes (so you can do Navigator.pushNamed('/profile'))
      routes: {
        '/home': (_) => const HomePage(),
        '/profile': (_) => const ProfileInfoPage(),
      },

      // Listen to auth state and show Login or Home
      home: StreamBuilder<User?>(
        stream: AuthService().authStateChanges,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // Not logged in
          if (snap.data == null) {
            return const LoginPage();
          }

          // Logged in → go to HomePage
          return const HomePage();
        },
      ),
    );
  }
}
