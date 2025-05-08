import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/category_model.dart';
import '../services/local_database_service.dart';

class CategoryProvider with ChangeNotifier {
  final LocalDatabaseService _databaseService = LocalDatabaseService();

  List<CategoryModel> _categories = [];
  List<CategoryModel> _expenseCategories = [];
  List<CategoryModel> _incomeCategories = [];
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _refreshTimer;

  // Getters
  List<CategoryModel> get categories => _categories;
  List<CategoryModel> get expenseCategories => _expenseCategories;
  List<CategoryModel> get incomeCategories => _incomeCategories;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Initialize categories for a user
  Future<void> initCategories(String userId) async {
    _setLoading(true);
    _clearError();

    try {
      // Initialize default categories if needed
      await _databaseService.initializeDefaultCategories(userId);

      // Fetch all categories
      _categories = await _databaseService.getCategories(userId);

      // Split into expense and income categories
      _expenseCategories = _categories.where((cat) => !cat.isIncome).toList();
      _incomeCategories = _categories.where((cat) => cat.isIncome).toList();

      // Set up periodic refresh (every 30 seconds)
      _refreshTimer?.cancel();
      _refreshTimer = Timer.periodic(
          Duration(seconds: 30), (_) => _refreshCategories(userId));

      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // Refresh categories from local database
  Future<void> _refreshCategories(String userId) async {
    try {
      _categories = await _databaseService.getCategories(userId);
      _expenseCategories = _categories.where((cat) => !cat.isIncome).toList();
      _incomeCategories = _categories.where((cat) => cat.isIncome).toList();
      notifyListeners();
    } catch (e) {
      // Silent error handling for background refresh
      if (kDebugMode) {
        print('Error refreshing categories: $e');
      }
    }
  }

  // Add a new category
  Future<bool> addCategory(CategoryModel category) async {
    _setLoading(true);
    _clearError();

    try {
      await _databaseService.addCategory(category);
      // Refresh the categories list
      _categories =
          await _databaseService.getCategories(category.createdBy ?? '');
      _expenseCategories = _categories.where((cat) => !cat.isIncome).toList();
      _incomeCategories = _categories.where((cat) => cat.isIncome).toList();
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Update an existing category
  Future<bool> updateCategory(CategoryModel category) async {
    _setLoading(true);
    _clearError();

    try {
      await _databaseService.updateCategory(category);
      // Refresh the categories list
      _categories =
          await _databaseService.getCategories(category.createdBy ?? '');
      _expenseCategories = _categories.where((cat) => !cat.isIncome).toList();
      _incomeCategories = _categories.where((cat) => cat.isIncome).toList();
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Delete a category
  Future<bool> deleteCategory(String id) async {
    _setLoading(true);
    _clearError();

    try {
      await _databaseService.deleteCategory(id);
      // Find the user ID from the categories we have
      final userId =
          _categories.firstWhere((cat) => cat.id == id).createdBy ?? '';
      // Refresh the categories list
      _categories = await _databaseService.getCategories(userId);
      _expenseCategories = _categories.where((cat) => !cat.isIncome).toList();
      _incomeCategories = _categories.where((cat) => cat.isIncome).toList();
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Get a category by ID
  CategoryModel? getCategoryById(String id) {
    try {
      return _categories.firstWhere((cat) => cat.id == id);
    } catch (e) {
      return null;
    }
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
