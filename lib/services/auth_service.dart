import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'dart:io';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  bool _isOnline = true;

  AuthService() {
    _checkConnectivity();
    _setupPersistence();
  }

  // Set up Firebase persistence
  Future<void> _setupPersistence() async {
    try {
      // Set to no persistence to avoid caching issues during testing
      await _auth.setPersistence(Persistence.LOCAL);
      if (kDebugMode) {
        print('Firebase persistence set to LOCAL');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error setting Firebase persistence: $e');
      }
    }
  }

  // Check internet connectivity
  Future<void> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      _isOnline = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      _isOnline = false;
    }
  }

  // Getter for online status
  bool get isOnline => _isOnline;

  // Update online status
  Future<bool> updateOnlineStatus() async {
    await _checkConnectivity();
    return _isOnline;
  }

  // Auth state stream
  Stream<UserModel> get authStateChanges =>
      _auth.authStateChanges().map((User? user) {
        if (user != null) {
          return UserModel.fromFirebaseUser(user);
        }
        return UserModel.empty();
      });

  // Current user
  UserModel get currentUser {
    final user = _auth.currentUser;
    if (user != null) {
      return UserModel.fromFirebaseUser(user);
    }
    return UserModel.empty();
  }

  // Force clear auth state
  Future<void> clearAuthState() async {
    try {
      if (kDebugMode) {
        print('Clearing Firebase auth state...');
      }

      // Force token refresh
      if (_auth.currentUser != null) {
        await _auth.currentUser!.reload();
        await _auth.currentUser!.getIdToken(true);
      }

      if (kDebugMode) {
        print('Auth state cleared');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing auth state: $e');
      }
    }
  }

  // Sign in with email and password
  Future<UserModel> signInWithEmailAndPassword(
      String email, String password) async {
    // Clear any stale auth state first
    await clearAuthState();

    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = result.user;
      if (user == null) {
        throw Exception('Sign in failed: no user returned');
      }

      if (kDebugMode) {
        print('Sign in successful: ${user.uid}');
      }

      return UserModel.fromFirebaseUser(user);
    } catch (e) {
      if (kDebugMode) {
        print('Sign in error: $e');
      }
      rethrow;
    }
  }

  // Sign up with email and password
  Future<UserModel> signUpWithEmailAndPassword(
      String email, String password, String name) async {
    // Clear any stale auth state first
    await clearAuthState();

    try {
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = result.user;
      if (user == null) {
        throw Exception('Sign up failed: no user returned');
      }

      // Update the user's display name
      await user.updateDisplayName(name);

      if (kDebugMode) {
        print('Sign up successful: ${user.uid}');
      }

      return UserModel.fromFirebaseUser(user);
    } catch (e) {
      if (kDebugMode) {
        print('Sign up error: $e');
      }
      rethrow;
    }
  }

  // Sign in with Google
  Future<UserModel> signInWithGoogle() async {
    // Clear any stale auth state first
    await clearAuthState();

    try {
      // First sign out of Google to clear any previous sessions
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      // Try using the Firebase auth provider method
      final GoogleAuthProvider googleProvider = GoogleAuthProvider();

      // Add some additional parameters to prevent caching
      googleProvider.setCustomParameters({
        'prompt': 'select_account',
        'login_hint': DateTime.now().millisecondsSinceEpoch.toString(),
      });

      final UserCredential userCredential =
          await _auth.signInWithProvider(googleProvider);

      final User? user = userCredential.user;
      if (user == null) {
        throw Exception('Google sign in failed: no user returned');
      }

      if (kDebugMode) {
        print('Google sign in successful: ${user.uid}');
      }

      return UserModel.fromFirebaseUser(user);
    } catch (e) {
      if (kDebugMode) {
        print('Google sign in error: $e');
      }
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    if (kDebugMode) {
      print('Starting sign out process...');
    }

    // First try to sign out from Google
    try {
      if (kDebugMode) {
        print('Signing out from Google...');
      }
      await _googleSignIn.signOut();
      if (kDebugMode) {
        print('Google sign out successful');
      }
    } catch (e) {
      // Continue even if Google sign out fails
      if (kDebugMode) {
        print('Google sign out error (continuing anyway): $e');
      }
    }

    // Then sign out from Firebase
    try {
      if (kDebugMode) {
        print('Signing out from Firebase...');
      }
      await _auth.signOut();

      // Clear any cached state
      await clearCaches();

      if (kDebugMode) {
        print('Firebase sign out successful');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Firebase sign out error: $e');
      }
      rethrow;
    }
  }

  // Clean up any caches
  Future<void> clearCaches() async {
    try {
      // Wait for a moment to ensure Firebase clears its internal state
      await Future.delayed(Duration(milliseconds: 500));

      // Retry sign out to be sure
      try {
        await _auth.signOut();
      } catch (_) {}

      if (kDebugMode) {
        print('Auth caches cleared');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing caches: $e');
      }
    }
  }

  // Password reset
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      if (kDebugMode) {
        print('Password reset error: $e');
      }
      rethrow;
    }
  }
}
