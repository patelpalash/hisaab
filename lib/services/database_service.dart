import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/transaction_model.dart';
import '../models/category_model.dart';
import '../models/budget_model.dart';
import '../models/recurring_transaction_model.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collections
  final CollectionReference _usersCollection;
  final CollectionReference _transactionsCollection;
  final CollectionReference _categoriesCollection;
  final CollectionReference _budgetsCollection;
  final CollectionReference _recurringTransactionsCollection;

  DatabaseService()
      : _usersCollection = FirebaseFirestore.instance.collection('users'),
        _transactionsCollection =
            FirebaseFirestore.instance.collection('transactions'),
        _categoriesCollection =
            FirebaseFirestore.instance.collection('categories'),
        _budgetsCollection = FirebaseFirestore.instance.collection('budgets'),
        _recurringTransactionsCollection =
            FirebaseFirestore.instance.collection('recurring_transactions');

  // USERS

  // Create or update user data
  Future<void> saveUser(UserModel user) async {
    try {
      await _usersCollection.doc(user.uid).set(
            user.toMap(),
            SetOptions(merge: true),
          );
    } catch (e) {
      if (kDebugMode) {
        print('Error saving user: $e');
      }
      rethrow;
    }
  }

  // Get user data
  Future<UserModel?> getUser(String uid) async {
    try {
      final doc = await _usersCollection.doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data()! as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting user: $e');
      }
      rethrow;
    }
  }

  // TRANSACTIONS

  // Add a new transaction
  Future<String> addTransaction(TransactionModel transaction) async {
    try {
      // If ID is empty, generate one
      final String id = transaction.id.isEmpty
          ? _transactionsCollection.doc().id
          : transaction.id;

      final TransactionModel transactionWithId = transaction.copyWith(id: id);

      await _transactionsCollection.doc(id).set(transactionWithId.toMap());
      return id;
    } catch (e) {
      if (kDebugMode) {
        print('Error adding transaction: $e');
      }
      rethrow;
    }
  }

  // Update an existing transaction
  Future<void> updateTransaction(TransactionModel transaction) async {
    try {
      await _transactionsCollection
          .doc(transaction.id)
          .update(transaction.copyWith(updatedAt: DateTime.now()).toMap());
    } catch (e) {
      if (kDebugMode) {
        print('Error updating transaction: $e');
      }
      rethrow;
    }
  }

  // Delete a transaction
  Future<void> deleteTransaction(String id) async {
    try {
      await _transactionsCollection.doc(id).delete();
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting transaction: $e');
      }
      rethrow;
    }
  }

  // Get all transactions for a user
  Stream<List<TransactionModel>> getTransactionsStream(String userId) {
    return _transactionsCollection
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) =>
                TransactionModel.fromMap(doc.data() as Map<String, dynamic>))
            .toList());
  }

  // Get recent transactions (limited number)
  Stream<List<TransactionModel>> getRecentTransactionsStream(String userId,
      {int limit = 5}) {
    return _transactionsCollection
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) =>
                TransactionModel.fromMap(doc.data() as Map<String, dynamic>))
            .toList());
  }

  // CATEGORIES

  // Initialize default categories for a new user
  Future<void> initializeDefaultCategories(String userId) async {
    try {
      // Add default expense categories
      for (var category in CategoryModel.defaultExpenseCategories()) {
        final categoryWithUserId = category.copyWith(createdBy: userId);
        await _categoriesCollection
            .doc(categoryWithUserId.id)
            .set(categoryWithUserId.toMap());
      }

      // Add default income categories
      for (var category in CategoryModel.defaultIncomeCategories()) {
        final categoryWithUserId = category.copyWith(createdBy: userId);
        await _categoriesCollection
            .doc(categoryWithUserId.id)
            .set(categoryWithUserId.toMap());
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing default categories: $e');
      }
      rethrow;
    }
  }

  // Add a new custom category
  Future<String> addCategory(CategoryModel category) async {
    try {
      // If ID is empty, generate one
      final String id =
          category.id.isEmpty ? _categoriesCollection.doc().id : category.id;

      final CategoryModel categoryWithId = category.copyWith(id: id);

      await _categoriesCollection.doc(id).set(categoryWithId.toMap());
      return id;
    } catch (e) {
      if (kDebugMode) {
        print('Error adding category: $e');
      }
      rethrow;
    }
  }

  // Update an existing category
  Future<void> updateCategory(CategoryModel category) async {
    try {
      await _categoriesCollection.doc(category.id).update(category.toMap());
    } catch (e) {
      if (kDebugMode) {
        print('Error updating category: $e');
      }
      rethrow;
    }
  }

  // Delete a category (only if it's not a default one)
  Future<void> deleteCategory(String id) async {
    try {
      final doc = await _categoriesCollection.doc(id).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final isDefault = data['isDefault'] ?? false;

        if (isDefault) {
          throw Exception('Cannot delete default category');
        }

        await _categoriesCollection.doc(id).delete();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting category: $e');
      }
      rethrow;
    }
  }

  // Get all categories for a user
  Stream<List<CategoryModel>> getCategoriesStream(String userId) {
    return _categoriesCollection
        .where('createdBy', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) =>
                CategoryModel.fromMap(doc.data() as Map<String, dynamic>))
            .toList());
  }

  // Get categories by type (income or expense)
  Stream<List<CategoryModel>> getCategoriesByTypeStream(
      String userId, bool isIncome) {
    return _categoriesCollection
        .where('createdBy', isEqualTo: userId)
        .where('isIncome', isEqualTo: isIncome)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) =>
                CategoryModel.fromMap(doc.data() as Map<String, dynamic>))
            .toList());
  }

  // BUDGETS

  // Add a new budget
  Future<String> addBudget(BudgetModel budget) async {
    try {
      // If ID is empty, generate one
      final String id =
          budget.id.isEmpty ? _budgetsCollection.doc().id : budget.id;

      final BudgetModel budgetWithId = budget.copyWith(id: id);

      await _budgetsCollection.doc(id).set(budgetWithId.toMap());
      return id;
    } catch (e) {
      if (kDebugMode) {
        print('Error adding budget: $e');
      }
      rethrow;
    }
  }

  // Update an existing budget
  Future<void> updateBudget(BudgetModel budget) async {
    try {
      await _budgetsCollection
          .doc(budget.id)
          .update(budget.copyWith(updatedAt: DateTime.now()).toMap());
    } catch (e) {
      if (kDebugMode) {
        print('Error updating budget: $e');
      }
      rethrow;
    }
  }

  // Delete a budget
  Future<void> deleteBudget(String id) async {
    try {
      await _budgetsCollection.doc(id).delete();
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting budget: $e');
      }
      rethrow;
    }
  }

  // Get all budgets for a user
  Stream<List<BudgetModel>> getBudgetsStream(String userId) {
    return _budgetsCollection
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) =>
                BudgetModel.fromMap(doc.data() as Map<String, dynamic>))
            .toList());
  }

  // Get active budgets for the current month
  Stream<List<BudgetModel>> getCurrentMonthBudgetsStream(String userId) {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    return _budgetsCollection
        .where('userId', isEqualTo: userId)
        .where('startDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
        .where('endDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) =>
                BudgetModel.fromMap(doc.data() as Map<String, dynamic>))
            .toList());
  }

  // RECURRING TRANSACTIONS

  // Add a new recurring transaction
  Future<String> addRecurringTransaction(
      RecurringTransactionModel recurringTransaction) async {
    try {
      // If ID is empty, generate one
      final String id = recurringTransaction.id.isEmpty
          ? _recurringTransactionsCollection.doc().id
          : recurringTransaction.id;

      final RecurringTransactionModel recurringWithId =
          recurringTransaction.copyWith(id: id);

      await _recurringTransactionsCollection
          .doc(id)
          .set(recurringWithId.toMap());
      return id;
    } catch (e) {
      if (kDebugMode) {
        print('Error adding recurring transaction: $e');
      }
      rethrow;
    }
  }

  // Update an existing recurring transaction
  Future<void> updateRecurringTransaction(
      RecurringTransactionModel recurringTransaction) async {
    try {
      await _recurringTransactionsCollection
          .doc(recurringTransaction.id)
          .update(
              recurringTransaction.copyWith(updatedAt: DateTime.now()).toMap());
    } catch (e) {
      if (kDebugMode) {
        print('Error updating recurring transaction: $e');
      }
      rethrow;
    }
  }

  // Delete a recurring transaction
  Future<void> deleteRecurringTransaction(String id) async {
    try {
      await _recurringTransactionsCollection.doc(id).delete();
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting recurring transaction: $e');
      }
      rethrow;
    }
  }

  // Get all recurring transactions for a user
  Stream<List<RecurringTransactionModel>> getRecurringTransactionsStream(
      String userId) {
    return _recurringTransactionsCollection
        .where('userId', isEqualTo: userId)
        .orderBy('startDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RecurringTransactionModel.fromMap(
                doc.data() as Map<String, dynamic>))
            .toList());
  }

  // Get active recurring transactions
  Stream<List<RecurringTransactionModel>> getActiveRecurringTransactionsStream(
      String userId) {
    final now = DateTime.now().toIso8601String();

    return _recurringTransactionsCollection
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .orderBy('startDate', descending: true)
        .snapshots()
        .map((snapshot) {
      final docs = snapshot.docs;
      final List<RecurringTransactionModel> activeRecurrings = [];

      for (var doc in docs) {
        final recurring = RecurringTransactionModel.fromMap(
            doc.data() as Map<String, dynamic>);
        // Filter by end date client-side (Firestore can't do this filtering well)
        if (recurring.endDate == null ||
            recurring.endDate!.isAfter(DateTime.now())) {
          activeRecurrings.add(recurring);
        }
      }

      return activeRecurrings;
    });
  }
}
