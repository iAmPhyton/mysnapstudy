import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final GoogleSignIn? _googleSignIn;

  AuthService() {
    // Only instantiate GoogleSignIn on mobile/desktop platforms.
    // On Flutter Web, FirebaseAuth.signInWithPopup is used directly to avoid
    // google_sign_in_web client_id assertion crashes.
    if (!kIsWeb) {
      _googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );
    } else {
      _googleSignIn = null;
    }
  }

  // Stream to listen to real-time auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get current authenticated user
  User? get currentUser => _auth.currentUser;

  bool get isAuthenticated => _auth.currentUser != null;

  // Google Sign-In implementation
  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // Web uses Firebase Auth popup flow directly
        final GoogleAuthProvider authProvider = GoogleAuthProvider();
        authProvider.addScope('email');
        authProvider.addScope('profile');
        final UserCredential credential =
            await _auth.signInWithPopup(authProvider);
        notifyListeners();
        return credential;
      } else {
        // Mobile flow using GoogleSignIn
        final GoogleSignInAccount? googleUser = await _googleSignIn!.signIn();

        if (googleUser == null) {
          // User aborted the sign-in flow
          return null;
        }

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final UserCredential userCredential =
            await _auth.signInWithCredential(credential);
        notifyListeners();
        return userCredential;
      }
    } catch (e) {
      debugPrint('Error during Google Sign-In: $e');
      rethrow;
    }
  }

  // Sign out flow handling web and mobile platforms safely
  Future<void> signOut() async {
    try {
      if (!kIsWeb && _googleSignIn != null) {
        try {
          await _googleSignIn.signOut();
        } catch (e) {
          debugPrint('Error signing out of GoogleSignIn: $e');
        }
      }
      await _auth.signOut();
      notifyListeners();
    } catch (e) {
      debugPrint('Error signing out: $e');
      rethrow;
    }
  }
}

