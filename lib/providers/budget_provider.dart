import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/budget_model.dart';
import '../services/local_database_service.dart';
import '../models/transaction_model.dart';

class BudgetProvider with ChangeNotifier {
  final LocalDatabaseService _databaseService = LocalDatabaseService();

  List<BudgetModel> _budgets = [];
  List<BudgetModel> _currentMonthBudgets = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<BudgetModel> get budgets => _budgets;
  List<BudgetModel> get currentMonthBudgets => _currentMonthBudgets;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Initialize budgets for a user
  Future<void> initBudgets(String userId) async {
    _setLoading(true);
    _clearError();

    try {
      // Load all budgets
      _budgets = await _databaseService.getBudgets(userId);

      // Load current month budgets
      _currentMonthBudgets =
          await _databaseService.getCurrentMonthBudgets(userId);

      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // Add a new budget
  Future<bool> addBudget(BudgetModel budget) async {
    _setLoading(true);
    _clearError();

    try {
      await _databaseService.addBudget(budget);
      // Refresh budgets after adding
      _budgets = await _databaseService.getBudgets(budget.userId);
      _currentMonthBudgets =
          await _databaseService.getCurrentMonthBudgets(budget.userId);
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Update an existing budget
  Future<bool> updateBudget(BudgetModel budget) async {
    _setLoading(true);
    _clearError();

    try {
      await _databaseService.updateBudget(budget);
      // Refresh budgets after updating
      _budgets = await _databaseService.getBudgets(budget.userId);
      _currentMonthBudgets =
          await _databaseService.getCurrentMonthBudgets(budget.userId);
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Delete a budget
  Future<bool> deleteBudget(String id) async {
    _setLoading(true);
    _clearError();

    // First find the userId from the budget being deleted
    final budget = _budgets.firstWhere((b) => b.id == id);
    final userId = budget.userId;

    try {
      await _databaseService.deleteBudget(id);
      // Refresh budgets after deleting
      _budgets = await _databaseService.getBudgets(userId);
      _currentMonthBudgets =
          await _databaseService.getCurrentMonthBudgets(userId);
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Get budget for a specific category in the current month
  BudgetModel? getBudgetForCategory(String categoryId) {
    try {
      return _currentMonthBudgets.firstWhere((b) => b.categoryId == categoryId);
    } catch (e) {
      return null;
    }
  }

  // Get overall budget (budget without a category)
  BudgetModel? getOverallBudget() {
    try {
      return _currentMonthBudgets.firstWhere((b) => b.categoryId == null);
    } catch (e) {
      return null;
    }
  }

  // Calculate budget spending progress
  double getBudgetProgress(
      BudgetModel budget, List<TransactionModel> transactions) {
    final totalSpent = getTotalSpentForBudget(budget, transactions);

    // Calculate progress (0.0 to 1.0)
    return budget.amount > 0
        ? (totalSpent / budget.amount).clamp(0.0, 1.0)
        : 0.0;
  }

  // Get total spent amount for a budget
  double getTotalSpentForBudget(
      BudgetModel budget, List<TransactionModel> transactions) {
    // Filter transactions by date range and category if applicable
    final filteredTransactions = transactions.where((t) {
      // Check if transaction date is within budget period (inclusive of end date)
      final inDateRange =
          t.date.isAfter(budget.startDate.subtract(const Duration(days: 1))) &&
              t.date.isBefore(budget.endDate.add(const Duration(days: 1)));

      // If this is a category budget, only include transactions for this category
      final matchesCategory =
          budget.categoryId != null ? t.categoryId == budget.categoryId : true;

      // Only include expenses
      return t.isExpense && inDateRange && matchesCategory;
    }).toList();

    // Sum the transactions
    return filteredTransactions.fold<double>(
        0, (sum, transaction) => sum + transaction.amount);
  }

  // Get remaining budget amount
  double getRemainingAmount(
      BudgetModel budget, List<TransactionModel> transactions) {
    final totalSpent = getTotalSpentForBudget(budget, transactions);
    return (budget.amount - totalSpent).clamp(0.0, double.infinity);
  }

  // Create a new monthly budget
  Future<BudgetModel> createMonthlyBudget({
    required String userId,
    required String name,
    required double amount,
    String? categoryId,
  }) async {
    final String id = DateTime.now().millisecondsSinceEpoch.toString();
    final DateTime now = DateTime.now();

    // Create a monthly budget starting from current month
    final DateTime startDate = DateTime(now.year, now.month, 1);
    final DateTime endDate = DateTime(
      now.month == 12 ? now.year + 1 : now.year,
      now.month == 12 ? 1 : now.month + 1,
      0, // Last day of current month
    );

    return BudgetModel(
      id: id,
      userId: userId,
      name: name,
      amount: amount,
      categoryId: categoryId,
      startDate: startDate,
      endDate: endDate,
      isRecurring: true,
      recurrenceType: 'monthly',
      createdAt: now,
      updatedAt: now,
    );
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
