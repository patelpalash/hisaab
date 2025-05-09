import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/local_database_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final LocalDatabaseService _databaseService = LocalDatabaseService();

  UserModel _user = UserModel.empty();
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  UserModel get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user.isAuthenticated;

  // Constructor - listen to auth state changes
  AuthProvider() {
    _authService.authStateChanges.listen((UserModel user) {
      _user = user;
      notifyListeners();
    });
  }

  // Sign in with email and password
  Future<bool> signInWithEmailAndPassword(String email, String password) async {
    _setLoading(true);
    _clearError();

    try {
      _user = await _authService.signInWithEmailAndPassword(email, password);

      // Check if user exists in local database
      final existingUser = await _databaseService.getUser(_user.uid);
      if (existingUser == null) {
        // Save user data to local database
        await _databaseService.saveUser(_user);
      }

      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Sign up with email and password
  Future<bool> signUpWithEmailAndPassword(
      String email, String password, String name) async {
    _setLoading(true);
    _clearError();

    try {
      _user =
          await _authService.signUpWithEmailAndPassword(email, password, name);

      // Save user data to local database
      await _databaseService.saveUser(_user);

      // Initialize default categories for the new user
      await _databaseService.initializeDefaultCategories(_user.uid);

      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Sign in with Google
  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    _clearError();

    try {
      _user = await _authService.signInWithGoogle();

      // Check if this is a new user (first time sign in)
      final existingUser = await _databaseService.getUser(_user.uid);
      if (existingUser == null) {
        // Save user data to local database
        await _databaseService.saveUser(_user);

        // Initialize default categories for the new user
        await _databaseService.initializeDefaultCategories(_user.uid);
      }

      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Sign out
  Future<void> signOut() async {
    _setLoading(true);
    _clearError();

    try {
      // Set user to empty before signout to prevent state conflicts
      _user = UserModel.empty();
      notifyListeners();

      // Wait a moment before calling signOut to avoid race conditions
      await Future.delayed(Duration(milliseconds: 300));
      await _authService.signOut();

      // Reset local database references if needed
      await _clearLocalState();

      // Clear any cached data
      await Future.delayed(Duration(milliseconds: 500));
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // Clear local database state if needed
  Future<void> _clearLocalState() async {
    try {
      // Here you could add additional cleanup for your local database if needed
      if (kDebugMode) {
        print('Cleared local authentication state');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing local state: $e');
      }
    }
  }

  // Force a reauth by clearing and reinitializing
  Future<void> forceReauthenticate() async {
    _setLoading(true);
    try {
      await signOut();
      await Future.delayed(Duration(seconds: 1));
      if (kDebugMode) {
        print('Auth reset complete, ready for new login');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error during force reauth: $e');
      }
    } finally {
      _setLoading(false);
    }
  }

  // Send password reset email
  Future<bool> sendPasswordResetEmail(String email) async {
    _setLoading(true);
    _clearError();

    try {
      await _authService.sendPasswordResetEmail(email);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
