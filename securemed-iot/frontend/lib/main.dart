import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/firebase_auth_service.dart';
import 'services/mock_auth_service.dart';
import 'providers/auth_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  AuthService authService;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    authService = FirebaseAuthService();
    debugPrint('[SecureMed IoT] Connected to Firebase Core.');
  } catch (e) {
    debugPrint('[SecureMed IoT] Firebase initialization notice: $e');
    debugPrint('[SecureMed IoT] Initializing MockAuthService for offline testing / prototype mode.');
    authService = MockAuthService(seedSampleUsers: true);
  }

  runApp(SecureMedApp(authService: authService));
}

class SecureMedApp extends StatelessWidget {
  final AuthService authService;

  const SecureMedApp({super.key, required this.authService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(authService: authService),
        ),
      ],
      child: MaterialApp(
        title: 'SecureMed IoT',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF8FAFC),
          colorScheme: const ColorScheme(
            brightness: Brightness.light,
            primary: Color(0xFF0A192F), // Dark navy blue primary
            onPrimary: Colors.white,
            secondary: Color(0xFF00796B), // Teal accent
            onSecondary: Colors.white,
            error: Color(0xFFDC2626),
            onError: Colors.white,
            surface: Colors.white,
            onSurface: Color(0xFF0F172A),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Color(0xFF0A192F),
            elevation: 0,
            scrolledUnderElevation: 1,
            centerTitle: false,
          ),
          cardTheme: CardThemeData(
            color: Colors.white,
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

/// Route Guard protecting all clinical & security views from unauthenticated access.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    switch (authProvider.status) {
      case AuthStatus.loading:
      case AuthStatus.initial:
        return const SplashScreen();
      case AuthStatus.authenticated:
        return const DashboardScreen();
      case AuthStatus.unauthenticated:
      case AuthStatus.error:
        return const AuthScreen();
    }
  }
}
