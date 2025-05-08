import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/transaction_model.dart';
import '../services/local_database_service.dart';

class TransactionProvider with ChangeNotifier {
  final LocalDatabaseService _databaseService = LocalDatabaseService();

  List<TransactionModel> _transactions = [];
  List<TransactionModel> _recentTransactions = [];
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _refreshTimer;

  // Getters
  List<TransactionModel> get transactions => _transactions;
  List<TransactionModel> get recentTransactions => _recentTransactions;
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
      // Load all transactions
      _transactions = await _databaseService.getTransactions(userId);

      // Load recent transactions
      _recentTransactions =
          await _databaseService.getRecentTransactions(userId);

      // Set up periodic refresh
      _refreshTimer?.cancel();
      _refreshTimer = Timer.periodic(
          Duration(seconds: 30), (_) => _refreshTransactions(userId));

      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // Refresh transactions from local database
  Future<void> _refreshTransactions(String userId) async {
    try {
      _transactions = await _databaseService.getTransactions(userId);
      _recentTransactions =
          await _databaseService.getRecentTransactions(userId);
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
    double income = 0;
    double expense = 0;

    for (var transaction in _transactions) {
      if (transaction.isExpense) {
        expense += transaction.amount;
      } else {
        income += transaction.amount;
      }
    }

    return income - expense;
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
