import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/transaction_model.dart';
import '../models/recurring_transaction_model.dart';
import '../services/local_database_service.dart';

class TransactionProvider with ChangeNotifier {
  final LocalDatabaseService _databaseService = LocalDatabaseService();

  List<TransactionModel> _transactions = [];
  List<TransactionModel> _recentTransactions = [];
  List<RecurringTransactionModel> _recurringTransactions = [];
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _refreshTimer;
  Timer? _recurringTransactionTimer;

  // Class-level variable to track last processing time
  DateTime _lastRecurringProcessTime =
      DateTime.now().subtract(const Duration(hours: 12));

  // Getters
  List<TransactionModel> get transactions => _transactions;
  List<TransactionModel> get recentTransactions => _recentTransactions;
  List<RecurringTransactionModel> get recurringTransactions =>
      _recurringTransactions;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Balance getters used in main.dart
  double get totalIncome => calculateIncome();
  double get totalExpenses => calculateExpenses();
  double get balance => calculateBalance();

  // Initialize transactions for a user
  void initTransactions(String userId) async {
    _setLoading(true);
    _clearError();

    try {
      // First, clean up any duplicate transactions from previous runs
      final int cleanedCount =
          await _databaseService.cleanupDuplicateRecurringTransactions(userId);
      if (cleanedCount > 0 && kDebugMode) {
        print('Cleaned up $cleanedCount duplicate recurring transactions');
      }

      // Process recurring transactions only if enough time has passed (at least 4 hours)
      final now = DateTime.now();
      if (now.difference(_lastRecurringProcessTime).inHours >= 4) {
        await _processRecurringTransactions(userId);
        _lastRecurringProcessTime = now; // Update last process time
      }

      // Load all transactions
      _transactions = await _databaseService.getTransactions(userId);

      // Load recent transactions
      _recentTransactions =
          await _databaseService.getRecentTransactions(userId);

      // Load recurring transactions
      _recurringTransactions =
          await _databaseService.getRecurringTransactions(userId);

      // Set up periodic refresh
      _refreshTimer?.cancel();
      _refreshTimer = Timer.periodic(
          Duration(seconds: 30), (_) => _refreshTransactions(userId));

      // Set up timer to process recurring transactions daily
      _recurringTransactionTimer?.cancel();
      _recurringTransactionTimer = Timer.periodic(
          Duration(hours: 12), (_) => _processRecurringTransactions(userId));

      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // Process recurring transactions
  Future<void> _processRecurringTransactions(String userId) async {
    try {
      if (kDebugMode) {
        print('Starting recurring transaction processing for user: $userId');
      }

      final List<TransactionModel> generatedTransactions =
          await _databaseService.processRecurringTransactions(userId);

      if (generatedTransactions.isNotEmpty) {
        if (kDebugMode) {
          print(
              'Generated ${generatedTransactions.length} recurring transactions:');
          for (var tx in generatedTransactions) {
            print('- ${tx.title}: \$${tx.amount} (${tx.date.toString()})');
          }
        }

        // If any transactions were generated, refresh the transaction lists
        await _refreshTransactions(userId);
      } else if (kDebugMode) {
        print('No recurring transactions were generated at this time.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error processing recurring transactions: $e');
      }
    }
  }

  // Refresh transactions from local database
  Future<void> _refreshTransactions(String userId) async {
    try {
      _transactions = await _databaseService.getTransactions(userId);
      _recentTransactions =
          await _databaseService.getRecentTransactions(userId);
      _recurringTransactions =
          await _databaseService.getRecurringTransactions(userId);
      notifyListeners();
    } catch (e) {
      // Silent error handling for background refresh
      if (kDebugMode) {
        print('Error refreshing transactions: $e');
      }
    }
  }

  // Add a new transaction
  Future<bool> addTransaction(TransactionModel transaction) async {
    _setLoading(true);
    _clearError();

    try {
      await _databaseService.addTransaction(transaction);
      // Refresh transactions after adding
      _transactions =
          await _databaseService.getTransactions(transaction.userId);
      _recentTransactions =
          await _databaseService.getRecentTransactions(transaction.userId);
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Add a recurring transaction
  Future<bool> addRecurringTransaction(
      RecurringTransactionModel recurringTransaction) async {
    _setLoading(true);
    _clearError();

    try {
      await _databaseService.addRecurringTransaction(recurringTransaction);
      // Refresh recurring transactions
      _recurringTransactions = await _databaseService
          .getRecurringTransactions(recurringTransaction.userId);
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Update a recurring transaction
  Future<bool> updateRecurringTransaction(
      RecurringTransactionModel recurringTransaction) async {
    _setLoading(true);
    _clearError();

    try {
      await _databaseService.updateRecurringTransaction(recurringTransaction);
      // Refresh recurring transactions
      _recurringTransactions = await _databaseService
          .getRecurringTransactions(recurringTransaction.userId);
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Delete a recurring transaction
  Future<bool> deleteRecurringTransaction(String id) async {
    _setLoading(true);
    _clearError();

    // First find the userId from the recurring transaction being deleted
    final recurringTransaction =
        _recurringTransactions.firstWhere((t) => t.id == id);
    final userId = recurringTransaction.userId;

    try {
      await _databaseService.deleteRecurringTransaction(id);
      // Refresh recurring transactions
      _recurringTransactions =
          await _databaseService.getRecurringTransactions(userId);
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Get active recurring transactions
  Future<List<RecurringTransactionModel>> getActiveRecurringTransactions(
      String userId) async {
    try {
      return await _databaseService.getActiveRecurringTransactions(userId);
    } catch (e) {
      if (kDebugMode) {
        print('Error getting active recurring transactions: $e');
      }
      return [];
    }
  }

  // Update an existing transaction
  Future<bool> updateTransaction(TransactionModel transaction) async {
    _setLoading(true);
    _clearError();

    try {
      await _databaseService.updateTransaction(transaction);
      // Refresh transactions after updating
      _transactions =
          await _databaseService.getTransactions(transaction.userId);
      _recentTransactions =
          await _databaseService.getRecentTransactions(transaction.userId);
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Delete a transaction
  Future<bool> deleteTransaction(String id) async {
    _setLoading(true);
    _clearError();

    // First find the userId from the transaction being deleted
    final transaction = _transactions.firstWhere((t) => t.id == id);
    final userId = transaction.userId;

    try {
      await _databaseService.deleteTransaction(id);
      // Refresh transactions after deleting
      _transactions = await _databaseService.getTransactions(userId);
      _recentTransactions =
          await _databaseService.getRecentTransactions(userId);
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Calculate total balance
  double calculateBalance() {
    // Use the existing helper methods instead of recalculating
    return calculateIncome() - calculateExpenses();
  }

  // Calculate total income
  double calculateIncome() {
    return _transactions
        .where((transaction) => !transaction.isExpense)
        .fold(0, (sum, transaction) => sum + transaction.amount);
  }

  // Calculate total expenses
  double calculateExpenses() {
    return _transactions
        .where((transaction) => transaction.isExpense)
        .fold(0, (sum, transaction) => sum + transaction.amount);
  }

  // Calculate income for a specific account
  double calculateAccountIncome(String accountId) {
    return _transactions
        .where((transaction) =>
            !transaction.isExpense && transaction.accountId == accountId)
        .fold(0, (sum, transaction) => sum + transaction.amount);
  }

  // Calculate expenses for a specific account
  double calculateAccountExpenses(String accountId) {
    return _transactions
        .where((transaction) =>
            transaction.isExpense && transaction.accountId == accountId)
        .fold(0, (sum, transaction) => sum + transaction.amount);
  }

  // Get transactions for a specific account
  List<TransactionModel> getTransactionsForAccount(String accountId) {
    return _transactions
        .where((transaction) =>
            transaction.accountId == accountId ||
            transaction.toAccountId == accountId)
        .toList();
  }

  // Calculate account-specific balance (based on transactions, not the stored balance)
  double calculateAccountBalance(String accountId) {
    double income = calculateAccountIncome(accountId);
    double expense = calculateAccountExpenses(accountId);

    // Also consider transfers
    double transfersIn = _transactions
        .where((transaction) =>
            transaction.isTransfer && transaction.toAccountId == accountId)
        .fold(0, (sum, transaction) => sum + transaction.amount);

    double transfersOut = _transactions
        .where((transaction) =>
            transaction.isTransfer && transaction.accountId == accountId)
        .fold(0, (sum, transaction) => sum + transaction.amount);

    return income - expense + transfersIn - transfersOut;
  }

  // Dispose of resources
  @override
  void dispose() {
    _refreshTimer?.cancel();
    _recurringTransactionTimer?.cancel();
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

  // Manually clean up duplicate transactions
  Future<int> cleanupDuplicateTransactions(String userId) async {
    _setLoading(true);
    _clearError();

    try {
      final int cleanedCount =
          await _databaseService.cleanupDuplicateRecurringTransactions(userId);

      // Refresh transactions after cleanup
      _transactions = await _databaseService.getTransactions(userId);
      _recentTransactions =
          await _databaseService.getRecentTransactions(userId);

      notifyListeners();
      return cleanedCount;
    } catch (e) {
      _setError(e.toString());
      return 0;
    } finally {
      _setLoading(false);
    }
  }

  // Reset all transaction data
  Future<bool> resetAllTransactionData(String userId) async {
    _setLoading(true);
    _clearError();

    try {
      // Call the database service to reset all transaction data
      await _databaseService.resetAllTransactionData(userId);

      // Clear local lists
      _transactions = [];
      _recentTransactions = [];
      _recurringTransactions = [];

      // Reset processing time to prevent immediate recreation
      _lastRecurringProcessTime = DateTime.now();

      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }
}
