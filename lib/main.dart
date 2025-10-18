import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'providers/theme_provider.dart';
import 'providers/user_profile_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with platform-specific options
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully');
  } catch (e) {
    print('❌ Firebase initialization error: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => UserProfileProvider()),
      ],
      child: const KagriApp(),
    ),
  );
}

class KagriApp extends StatelessWidget {
  const KagriApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'KAGRI',
      theme: themeProvider.lightTheme,
      darkTheme: themeProvider.darkTheme,
      themeMode: themeProvider.themeMode,
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Auth wrapper to show login or home screen based on auth state
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Show home screen if logged in, login screen if not
        if (snapshot.hasData && snapshot.data != null) {
          return const HomeScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
