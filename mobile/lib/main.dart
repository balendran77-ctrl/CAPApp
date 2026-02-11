import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'services/api_service.dart';
import 'services/auth_provider.dart' as app_auth;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase. Use web options when running on web.
  try {
    if (kIsWeb) {
      await Firebase.initializeApp(options: firebaseOptions);
    } else {
      await Firebase.initializeApp();
    }
  } catch (e) {
    // If Firebase is not configured for native platforms (missing google-service files), continue.
    print('Firebase initialize error: $e');
  }

  try {
    if (Firebase.apps.isNotEmpty) {
      final auth = FirebaseAuth.instance;
      if (auth.currentUser == null) {
        await auth.signInAnonymously();
      }
    }
  } catch (e) {
    print('Firebase auth error: $e');
  }
  await ApiService.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => app_auth.AuthProvider()),
      ],
      child: MaterialApp(
        title: 'CAP App',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: const SplashScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<bool>(
        future: _checkAuthentication(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.data == true) {
            return const HomeScreen();
          } else {
            return const LoginScreen();
          }
        },
      ),
    );
  }

  Future<bool> _checkAuthentication() async {
    try {
      final health = await ApiService.checkServerHealth();
      if (!health) {
        // Server not available, use cached data or offline mode
        return true; // Allow to continue for now
      }
      // Try to fetch profile - if successful, user is authenticated
      await ApiService.getProfile();
      return true;
    } catch (e) {
      return false;
    }
  }
}
