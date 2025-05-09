import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/account_model.dart';
import '../services/local_database_service.dart';

class AccountProvider with ChangeNotifier {
  final LocalDatabaseService _databaseService = LocalDatabaseService();

  List<AccountModel> _accounts = [];
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _refreshTimer;

  // Getters
  List<AccountModel> get accounts => _accounts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Initialize accounts for a user
  Future<void> initAccounts(String userId) async {
    _setLoading(true);
    _clearError();

    try {
      // Initialize default accounts if needed
      await _databaseService.initializeDefaultAccounts(userId);

      // Fetch all accounts
      _accounts = await _databaseService.getAccounts(userId);

      // Set up periodic refresh (every 30 seconds)
      _refreshTimer?.cancel();
      _refreshTimer = Timer.periodic(
          Duration(seconds: 30), (_) => _refreshAccounts(userId));

      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // Refresh accounts from local database
  Future<void> _refreshAccounts(String userId) async {
    try {
      _accounts = await _databaseService.getAccounts(userId);
      notifyListeners();
    } catch (e) {
      // Silent error handling for background refresh
      if (kDebugMode) {
        print('Error refreshing accounts: $e');
      }
    }
  }

  // Add a new account
  Future<bool> addAccount(AccountModel account) async {
    _setLoading(true);
    _clearError();

    try {
      await _databaseService.addAccount(account);
      // Refresh the accounts list
      _accounts = await _databaseService.getAccounts(account.userId);
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Update an existing account
  Future<bool> updateAccount(AccountModel account) async {
    _setLoading(true);
    _clearError();

    try {
      await _databaseService.updateAccount(account);
      // Refresh the accounts list
      _accounts = await _databaseService.getAccounts(account.userId);
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Delete an account
  Future<bool> deleteAccount(String id) async {
    _setLoading(true);
    _clearError();

    try {
      // First find the user ID from the accounts we have
      final userId = _accounts.firstWhere((acct) => acct.id == id).userId;

      await _databaseService.deleteAccount(id);
      // Refresh the accounts list
      _accounts = await _databaseService.getAccounts(userId);
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Get an account by ID
  AccountModel? getAccountById(String id) {
    try {
      return _accounts.firstWhere((acct) => acct.id == id);
    } catch (e) {
      return null;
    }
  }

  // Process a transfer between accounts
  Future<bool> processTransfer({
    required String fromAccountId,
    required String toAccountId,
    required double amount,
    required String title,
    required String userId,
    String? notes,
  }) async {
    _setLoading(true);
    _clearError();

    // Maximum number of retries
    const maxRetries = 3;
    int retryCount = 0;

    while (retryCount < maxRetries) {
      try {
        // Create a transfer transaction with a back-off delay on retries
        if (retryCount > 0) {
          await Future.delayed(Duration(milliseconds: 300 * retryCount));
          if (kDebugMode) {
            print('Retrying transfer operation (attempt ${retryCount + 1})');
          }
        }

        final success = await _databaseService.createTransfer(
          fromAccountId: fromAccountId,
          toAccountId: toAccountId,
          amount: amount,
          title: title,
          userId: userId,
          notes: notes,
        );

        if (success) {
          // Refresh accounts to reflect new balances
          _accounts = await _databaseService.getAccounts(userId);
          notifyListeners();
        }

        return success;
      } catch (e) {
        // Handle database lock errors by retrying
        if (e.toString().contains('database is locked') &&
            retryCount < maxRetries - 1) {
          retryCount++;
          if (kDebugMode) {
            print('Database locked, retrying...');
          }
        } else {
          _setError(e.toString());
          return false;
        }
      }
    }

    // All retries failed
    _setError('Failed to process transfer after multiple attempts');
    _setLoading(false);
    return false;
  }

  // Dispose of resources
  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
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
