import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:async';
import '../models/user_model.dart';
import '../models/transaction_model.dart';
import '../models/category_model.dart';
import '../models/budget_model.dart';
import '../models/recurring_transaction_model.dart';
import 'package:flutter/material.dart';

class LocalDatabaseService {
  static final LocalDatabaseService _instance =
      LocalDatabaseService._internal();
  factory LocalDatabaseService() => _instance;
  LocalDatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'hisaab.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDb,
      onUpgrade: _upgradeDb,
    );
  }

  Future<void> _createDb(Database db, int version) async {
    // Create users table
    await db.execute('''
      CREATE TABLE users(
        uid TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT NOT NULL,
        photoUrl TEXT,
        isPremium INTEGER NOT NULL,
        createdAt TEXT NOT NULL,
        lastLogin TEXT
      )
    ''');

    // Create categories table
    await db.execute('''
      CREATE TABLE categories(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        iconCodePoint INTEGER NOT NULL,
        iconFontFamily TEXT,
        colorValue INTEGER NOT NULL,
        backgroundColorValue INTEGER NOT NULL,
        isIncome INTEGER NOT NULL,
        isDefault INTEGER NOT NULL,
        createdBy TEXT NOT NULL
      )
    ''');

    // Create transactions table
    await db.execute('''
      CREATE TABLE transactions(
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        categoryId TEXT NOT NULL,
        isExpense INTEGER NOT NULL,
        userId TEXT NOT NULL,
        notes TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT,
        FOREIGN KEY (categoryId) REFERENCES categories (id),
        FOREIGN KEY (userId) REFERENCES users (uid)
      )
    ''');

    // Create recurring transactions table
    await db.execute('''
      CREATE TABLE recurring_transactions(
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        categoryId TEXT NOT NULL,
        isExpense INTEGER NOT NULL,
        userId TEXT NOT NULL,
        notes TEXT,
        frequency TEXT NOT NULL,
        startDate TEXT NOT NULL,
        endDate TEXT,
        isActive INTEGER NOT NULL,
        dayOfMonth INTEGER,
        dayOfWeek INTEGER,
        createdAt TEXT NOT NULL,
        updatedAt TEXT,
        FOREIGN KEY (categoryId) REFERENCES categories (id),
        FOREIGN KEY (userId) REFERENCES users (uid)
      )
    ''');

    // Create budgets table
    await db.execute('''
      CREATE TABLE budgets(
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        name TEXT NOT NULL,
        amount REAL NOT NULL,
        categoryId TEXT,
        startDate TEXT NOT NULL,
        endDate TEXT NOT NULL,
        isRecurring INTEGER NOT NULL,
        recurrenceType TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT,
        FOREIGN KEY (userId) REFERENCES users (uid),
        FOREIGN KEY (categoryId) REFERENCES categories (id)
      )
    ''');
  }

  // Handle database upgrades
  Future<void> _upgradeDb(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Create recurring transactions table for users upgrading from version 1
      await db.execute('''
        CREATE TABLE IF NOT EXISTS recurring_transactions(
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          amount REAL NOT NULL,
          categoryId TEXT NOT NULL,
          isExpense INTEGER NOT NULL,
          userId TEXT NOT NULL,
          notes TEXT,
          frequency TEXT NOT NULL,
          startDate TEXT NOT NULL,
          endDate TEXT,
          isActive INTEGER NOT NULL,
          dayOfMonth INTEGER,
          dayOfWeek INTEGER,
          createdAt TEXT NOT NULL,
          updatedAt TEXT,
          FOREIGN KEY (categoryId) REFERENCES categories (id),
          FOREIGN KEY (userId) REFERENCES users (uid)
        )
      ''');
    }
  }

  // USERS

  Future<void> saveUser(UserModel user) async {
    final db = await database;
    await db.insert(
      'users',
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<UserModel?> getUser(String uid) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'uid = ?',
      whereArgs: [uid],
    );

    if (maps.isNotEmpty) {
      return UserModel.fromMap(maps.first);
    }
    return null;
  }

  // CATEGORIES

  Future<void> initializeDefaultCategories(String userId) async {
    final db = await database;

    // First check if there are already categories for this user
    final count = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM categories WHERE createdBy = ?',
      [userId],
    ));

    if (count == 0) {
      // Add default expense categories
      for (var category in CategoryModel.defaultExpenseCategories()) {
        final categoryWithUserId = category.copyWith(createdBy: userId);
        await db.insert(
          'categories',
          {
            'id': categoryWithUserId.id,
            'name': categoryWithUserId.name,
            'iconCodePoint': categoryWithUserId.icon.codePoint,
            'iconFontFamily': categoryWithUserId.icon.fontFamily,
            'colorValue': categoryWithUserId.color.value,
            'backgroundColorValue': categoryWithUserId.backgroundColor.value,
            'isIncome': categoryWithUserId.isIncome ? 1 : 0,
            'isDefault': categoryWithUserId.isDefault ? 1 : 0,
            'createdBy': categoryWithUserId.createdBy ?? userId,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // Add default income categories
      for (var category in CategoryModel.defaultIncomeCategories()) {
        final categoryWithUserId = category.copyWith(createdBy: userId);
        await db.insert(
          'categories',
          {
            'id': categoryWithUserId.id,
            'name': categoryWithUserId.name,
            'iconCodePoint': categoryWithUserId.icon.codePoint,
            'iconFontFamily': categoryWithUserId.icon.fontFamily,
            'colorValue': categoryWithUserId.color.value,
            'backgroundColorValue': categoryWithUserId.backgroundColor.value,
            'isIncome': categoryWithUserId.isIncome ? 1 : 0,
            'isDefault': categoryWithUserId.isDefault ? 1 : 0,
            'createdBy': categoryWithUserId.createdBy ?? userId,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
  }

  Future<String> addCategory(CategoryModel category) async {
    final db = await database;
    await db.insert(
      'categories',
      {
        'id': category.id,
        'name': category.name,
        'iconCodePoint': category.icon.codePoint,
        'iconFontFamily': category.icon.fontFamily,
        'colorValue': category.color.value,
        'backgroundColorValue': category.backgroundColor.value,
        'isIncome': category.isIncome ? 1 : 0,
        'isDefault': category.isDefault ? 1 : 0,
        'createdBy': category.createdBy ?? '',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return category.id;
  }

  Future<void> updateCategory(CategoryModel category) async {
    final db = await database;
    await db.update(
      'categories',
      {
        'name': category.name,
        'iconCodePoint': category.icon.codePoint,
        'iconFontFamily': category.icon.fontFamily,
        'colorValue': category.color.value,
        'backgroundColorValue': category.backgroundColor.value,
        'isIncome': category.isIncome ? 1 : 0,
        'isDefault': category.isDefault ? 1 : 0,
        'createdBy': category.createdBy ?? '',
      },
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<void> deleteCategory(String id) async {
    final db = await database;

    // First check if it's a default category
    final List<Map<String, dynamic>> maps = await db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      final isDefault = maps.first['isDefault'] == 1;
      if (isDefault) {
        throw Exception('Cannot delete default category');
      }
    }

    await db.delete(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<CategoryModel>> getCategories(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'categories',
      where: 'createdBy = ?',
      whereArgs: [userId],
    );

    return List.generate(maps.length, (i) {
      return CategoryModel(
        id: maps[i]['id'],
        name: maps[i]['name'],
        icon: IconData(
          maps[i]['iconCodePoint'],
          fontFamily: maps[i]['iconFontFamily'],
        ),
        color: Color(maps[i]['colorValue']),
        backgroundColor: Color(maps[i]['backgroundColorValue']),
        isIncome: maps[i]['isIncome'] == 1,
        isDefault: maps[i]['isDefault'] == 1,
        createdBy: maps[i]['createdBy'],
      );
    });
  }

  Future<List<CategoryModel>> getExpenseCategories(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'categories',
      where: 'createdBy = ? AND isIncome = 0',
      whereArgs: [userId],
    );

    return List.generate(maps.length, (i) {
      return CategoryModel(
        id: maps[i]['id'],
        name: maps[i]['name'],
        icon: IconData(
          maps[i]['iconCodePoint'],
          fontFamily: maps[i]['iconFontFamily'],
        ),
        color: Color(maps[i]['colorValue']),
        backgroundColor: Color(maps[i]['backgroundColorValue']),
        isIncome: maps[i]['isIncome'] == 1,
        isDefault: maps[i]['isDefault'] == 1,
        createdBy: maps[i]['createdBy'],
      );
    });
  }

  Future<List<CategoryModel>> getIncomeCategories(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'categories',
      where: 'createdBy = ? AND isIncome = 1',
      whereArgs: [userId],
    );

    return List.generate(maps.length, (i) {
      return CategoryModel(
        id: maps[i]['id'],
        name: maps[i]['name'],
        icon: IconData(
          maps[i]['iconCodePoint'],
          fontFamily: maps[i]['iconFontFamily'],
        ),
        color: Color(maps[i]['colorValue']),
        backgroundColor: Color(maps[i]['backgroundColorValue']),
        isIncome: maps[i]['isIncome'] == 1,
        isDefault: maps[i]['isDefault'] == 1,
        createdBy: maps[i]['createdBy'],
      );
    });
  }

  Future<CategoryModel?> getCategoryById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return CategoryModel(
        id: maps[0]['id'],
        name: maps[0]['name'],
        icon: IconData(
          maps[0]['iconCodePoint'],
          fontFamily: maps[0]['iconFontFamily'],
        ),
        color: Color(maps[0]['colorValue']),
        backgroundColor: Color(maps[0]['backgroundColorValue']),
        isIncome: maps[0]['isIncome'] == 1,
        isDefault: maps[0]['isDefault'] == 1,
        createdBy: maps[0]['createdBy'],
      );
    }
    return null;
  }

  // TRANSACTIONS

  Future<String> addTransaction(TransactionModel transaction) async {
    final db = await database;
    await db.insert(
      'transactions',
      transaction.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return transaction.id;
  }

  Future<void> updateTransaction(TransactionModel transaction) async {
    final db = await database;
    await db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<void> deleteTransaction(String id) async {
    final db = await database;
    await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<TransactionModel>> getTransactions(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'date DESC', // Sort by date descending (newest first)
    );

    return List.generate(maps.length, (i) {
      return TransactionModel.fromMap(maps[i]);
    });
  }

  Future<List<TransactionModel>> getRecentTransactions(String userId,
      {int limit = 5}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'date DESC',
      limit: limit,
    );

    return List.generate(maps.length, (i) {
      return TransactionModel(
        id: maps[i]['id'],
        title: maps[i]['title'],
        amount: maps[i]['amount'],
        date: DateTime.parse(maps[i]['date']),
        categoryId: maps[i]['categoryId'],
        isExpense: maps[i]['isExpense'] == 1,
        userId: maps[i]['userId'],
        notes: maps[i]['notes'],
        createdAt: DateTime.parse(maps[i]['createdAt']),
        updatedAt: maps[i]['updatedAt'] != null
            ? DateTime.parse(maps[i]['updatedAt'])
            : null,
      );
    });
  }

  // BUDGETS

  Future<String> addBudget(BudgetModel budget) async {
    final db = await database;
    await db.insert(
      'budgets',
      budget.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return budget.id;
  }

  Future<void> updateBudget(BudgetModel budget) async {
    final db = await database;
    await db.update(
      'budgets',
      budget.toMap(),
      where: 'id = ?',
      whereArgs: [budget.id],
    );
  }

  Future<void> deleteBudget(String id) async {
    final db = await database;
    await db.delete(
      'budgets',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<BudgetModel>> getBudgets(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'budgets',
      where: 'userId = ?',
      whereArgs: [userId],
    );

    return List.generate(maps.length, (i) {
      return BudgetModel.fromMap(maps[i]);
    });
  }

  Future<BudgetModel?> getBudgetById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'budgets',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return BudgetModel.fromMap(maps.first);
    }
    return null;
  }

  Future<List<BudgetModel>> getCurrentBudgets(String userId) async {
    final db = await database;
    final now = DateTime.now();

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT * FROM budgets
      WHERE userId = ?
      AND startDate <= ?
      AND endDate >= ?
    ''', [userId, now.toIso8601String(), now.toIso8601String()]);

    return List.generate(maps.length, (i) {
      return BudgetModel.fromMap(maps[i]);
    });
  }

  // Get budgets for the current month
  Future<List<BudgetModel>> getCurrentMonthBudgets(String userId) async {
    final db = await database;

    // Get current month's date range
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final lastDayOfMonth = DateTime(now.month == 12 ? now.year + 1 : now.year,
        now.month == 12 ? 1 : now.month + 1, 0 // Last day of current month
        );

    final List<Map<String, dynamic>> maps = await db.query(
      'budgets',
      where:
          'userId = ? AND ((startDate <= ? AND endDate >= ?) OR (startDate >= ? AND startDate <= ?))',
      whereArgs: [
        userId,
        lastDayOfMonth.toIso8601String(),
        firstDayOfMonth.toIso8601String(),
        firstDayOfMonth.toIso8601String(),
        lastDayOfMonth.toIso8601String(),
      ],
    );

    return List.generate(maps.length, (i) {
      return BudgetModel.fromMap(maps[i]);
    });
  }

  // RECURRING TRANSACTIONS

  Future<String> addRecurringTransaction(
      RecurringTransactionModel recurringTransaction) async {
    final db = await database;
    await db.insert(
      'recurring_transactions',
      recurringTransaction.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return recurringTransaction.id;
  }

  Future<void> updateRecurringTransaction(
      RecurringTransactionModel recurringTransaction) async {
    final db = await database;
    await db.update(
      'recurring_transactions',
      recurringTransaction.toMap(),
      where: 'id = ?',
      whereArgs: [recurringTransaction.id],
    );
  }

  Future<void> deleteRecurringTransaction(String id) async {
    final db = await database;
    await db.delete(
      'recurring_transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<RecurringTransactionModel>> getRecurringTransactions(
      String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'recurring_transactions',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'startDate DESC', // Sort by start date descending
    );

    return List.generate(maps.length, (i) {
      return RecurringTransactionModel.fromMap(maps[i]);
    });
  }

  Future<List<RecurringTransactionModel>> getActiveRecurringTransactions(
      String userId) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT * FROM recurring_transactions
      WHERE userId = ?
      AND isActive = 1
      AND (endDate IS NULL OR endDate >= ?)
      ORDER BY startDate DESC
    ''', [userId, now]);

    return List.generate(maps.length, (i) {
      return RecurringTransactionModel.fromMap(maps[i]);
    });
  }

  Future<RecurringTransactionModel?> getRecurringTransactionById(
      String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'recurring_transactions',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return RecurringTransactionModel.fromMap(maps.first);
    }
    return null;
  }

  // Process recurring transactions and create actual transactions
  Future<List<TransactionModel>> processRecurringTransactions(
      String userId) async {
    final db = await database;
    final List<RecurringTransactionModel> activeRecurrings =
        await getActiveRecurringTransactions(userId);
    final List<TransactionModel> createdTransactions = [];

    if (activeRecurrings.isEmpty) {
      return createdTransactions;
    }

    // Get the last processed date from metadata or use a default (yesterday)
    final DateTime now = DateTime.now();
    final DateTime yesterday = now.subtract(const Duration(days: 1));

    for (var recurring in activeRecurrings) {
      try {
        // Find the last generated transaction for this recurring transaction
        final List<Map<String, dynamic>> lastTransactionMaps =
            await db.rawQuery('''
          SELECT * FROM transactions
          WHERE userId = ?
          AND notes LIKE ?
          ORDER BY date DESC
          LIMIT 1
        ''', [userId, '%Recurring ID: ${recurring.id}%']);

        DateTime lastProcessedDate = yesterday;
        if (lastTransactionMaps.isNotEmpty) {
          final lastTransaction =
              TransactionModel.fromMap(lastTransactionMaps.first);
          lastProcessedDate = lastTransaction.date;
        } else if (recurring.startDate.isAfter(lastProcessedDate)) {
          lastProcessedDate =
              recurring.startDate.subtract(const Duration(days: 1));
        }

        // Calculate next date
        DateTime nextDate = recurring.getNextOccurrence(lastProcessedDate);

        // Create transactions for any dates between last processed and today
        while (!nextDate.isAfter(now) &&
            (recurring.endDate == null ||
                !nextDate.isAfter(recurring.endDate!))) {
          if (recurring.shouldGenerateForDate(nextDate)) {
            // Check if transaction already exists for this specific date and recurring ID
            final String dateString = nextDate.toIso8601String().split('T')[0];
            final List<Map<String, dynamic>> existingTransactions =
                await db.rawQuery('''
              SELECT * FROM transactions 
              WHERE userId = ? 
              AND notes LIKE ? 
              AND date LIKE ?
              LIMIT 1
            ''', [userId, '%Recurring ID: ${recurring.id}%', '$dateString%']);

            // Only create transaction if it doesn't already exist
            if (existingTransactions.isEmpty) {
              final transaction = recurring.generateTransaction(nextDate);
              await addTransaction(transaction);
              createdTransactions.add(transaction);
            }
          }
          nextDate = recurring.getNextOccurrence(nextDate);
        }
      } catch (e) {
        print('Error processing recurring transaction ${recurring.id}: $e');
        // Continue with next recurring transaction even if one fails
        continue;
      }
    }

    return createdTransactions;
  }

  // Cleanup duplicate recurring transactions for a given user
  Future<int> cleanupDuplicateRecurringTransactions(String userId) async {
    final db = await database;
    int deletedCount = 0;

    try {
      // Get all recurring transactions
      final List<RecurringTransactionModel> recurrings =
          await getRecurringTransactions(userId);

      for (var recurring in recurrings) {
        // Get all generated transactions for this recurring transaction
        final transactions = await db.query(
          'transactions',
          where: 'userId = ? AND notes LIKE ?',
          whereArgs: [userId, '%Recurring ID: ${recurring.id}%'],
          orderBy: 'date ASC',
        );

        // Group transactions by date to find duplicates
        final Map<String, List<Map<String, dynamic>>> transactionsByDate = {};

        for (var transaction in transactions) {
          final date = (transaction['date'] as String)
              .split('T')[0]; // Get just the date part
          transactionsByDate[date] = transactionsByDate[date] ?? [];
          transactionsByDate[date]!.add(transaction);
        }

        // For each date with more than one transaction, keep only the first one
        for (var date in transactionsByDate.keys) {
          if (transactionsByDate[date]!.length > 1) {
            // Keep the first transaction, delete the rest
            final toDelete = transactionsByDate[date]!.sublist(1);

            for (var transaction in toDelete) {
              await db.delete(
                'transactions',
                where: 'id = ?',
                whereArgs: [transaction['id']],
              );
              deletedCount++;
            }
          }
        }
      }

      return deletedCount;
    } catch (e) {
      print('Error cleaning up duplicate transactions: $e');
      return 0;
    }
  }

  // Completely reset transaction data for a user
  Future<void> resetAllTransactionData(String userId) async {
    final db = await database;

    try {
      // Delete all transactions
      await db.delete(
        'transactions',
        where: 'userId = ?',
        whereArgs: [userId],
      );

      // Delete all recurring transactions
      await db.delete(
        'recurring_transactions',
        where: 'userId = ?',
        whereArgs: [userId],
      );

      print('Successfully reset all transaction data for user: $userId');
    } catch (e) {
      print('Error resetting transaction data: $e');
      throw Exception('Failed to reset transaction data: $e');
    }
  }
}
