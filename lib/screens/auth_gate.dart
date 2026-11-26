import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';

/// Protects routes and views based on Firebase Authentication state.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        // While checking auth status, show clean loading view
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // If authenticated user is present, route to HomeScreen
        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;
          // Sync profile to Firestore in background
          FirestoreService().syncUserProfile(user);
          return HomeScreen(user: user);
        }

        // Otherwise, show LoginScreen
        return const LoginScreen();
      },
    );
  }
}
