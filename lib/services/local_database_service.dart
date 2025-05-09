import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/transaction_model.dart';
import '../models/category_model.dart';
import '../models/budget_model.dart';
import '../models/recurring_transaction_model.dart';
import '../models/account_model.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

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
      version: 3,
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

    // Create accounts table
    await db.execute('''
      CREATE TABLE accounts(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        balance REAL NOT NULL,
        iconCodePoint INTEGER NOT NULL,
        iconFontFamily TEXT,
        colorValue INTEGER NOT NULL,
        userId TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT,
        FOREIGN KEY (userId) REFERENCES users (uid)
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
        type TEXT,
        userId TEXT NOT NULL,
        notes TEXT,
        accountId TEXT,
        toAccountId TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT,
        FOREIGN KEY (categoryId) REFERENCES categories (id),
        FOREIGN KEY (userId) REFERENCES users (uid),
        FOREIGN KEY (accountId) REFERENCES accounts (id),
        FOREIGN KEY (toAccountId) REFERENCES accounts (id)
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

    if (oldVersion < 3) {
      // Create accounts table for users upgrading from version 2
      await db.execute('''
        CREATE TABLE IF NOT EXISTS accounts(
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          type TEXT NOT NULL,
          balance REAL NOT NULL,
          iconCodePoint INTEGER NOT NULL,
          iconFontFamily TEXT,
          colorValue INTEGER NOT NULL,
          userId TEXT NOT NULL,
          createdAt TEXT NOT NULL,
          updatedAt TEXT,
          FOREIGN KEY (userId) REFERENCES users (uid)
        )
      ''');

      // Alter transactions table to add account-related fields
      await db.execute('ALTER TABLE transactions ADD COLUMN type TEXT');
      await db.execute('ALTER TABLE transactions ADD COLUMN accountId TEXT');
      await db.execute('ALTER TABLE transactions ADD COLUMN toAccountId TEXT');
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
      return TransactionModel(
        id: maps[i]['id'],
        title: maps[i]['title'],
        amount: maps[i]['amount'],
        date: DateTime.parse(maps[i]['date']),
        categoryId: maps[i]['categoryId'],
        isExpense: maps[i]['isExpense'] == 1,
        type: maps[i]['type'] != null
            ? TransactionType.values.firstWhere(
                (e) => e.toString().split('.').last == maps[i]['type'],
                orElse: () => maps[i]['isExpense'] == 1
                    ? TransactionType.expense
                    : TransactionType.income)
            : maps[i]['isExpense'] == 1
                ? TransactionType.expense
                : TransactionType.income,
        userId: maps[i]['userId'],
        notes: maps[i]['notes'],
        accountId: maps[i]['accountId'],
        toAccountId: maps[i]['toAccountId'],
        createdAt: DateTime.parse(maps[i]['createdAt']),
        updatedAt: maps[i]['updatedAt'] != null
            ? DateTime.parse(maps[i]['updatedAt'])
            : null,
      );
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
        type: maps[i]['type'] != null
            ? TransactionType.values.firstWhere(
                (e) => e.toString().split('.').last == maps[i]['type'],
                orElse: () => maps[i]['isExpense'] == 1
                    ? TransactionType.expense
                    : TransactionType.income)
            : maps[i]['isExpense'] == 1
                ? TransactionType.expense
                : TransactionType.income,
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

  // ACCOUNTS

  // Initialize default accounts for a user
  Future<void> initializeDefaultAccounts(String userId) async {
    final db = await database;

    // First check if there are already accounts for this user
    final count = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM accounts WHERE userId = ?',
      [userId],
    ));

    if (count == 0) {
      // Add default accounts
      final defaultAccounts = AccountModel.defaultAccounts(userId);
      for (var account in defaultAccounts) {
        await db.insert(
          'accounts',
          account.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
  }

  // Get all accounts for a user
  Future<List<AccountModel>> getAccounts(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'accounts',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'name ASC',
    );

    return List.generate(maps.length, (i) {
      return AccountModel.fromMap(maps[i]);
    });
  }

  // Get account by ID
  Future<AccountModel?> getAccountById(String id, {Transaction? txn}) async {
    final db = txn ?? await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'accounts',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return AccountModel.fromMap(maps.first);
    }
    return null;
  }

  // Add an account
  Future<String> addAccount(AccountModel account) async {
    final db = await database;
    await db.insert(
      'accounts',
      account.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return account.id;
  }

  // Update an account
  Future<void> updateAccount(AccountModel account) async {
    final db = await database;
    await db.update(
      'accounts',
      account.toMap(),
      where: 'id = ?',
      whereArgs: [account.id],
    );
  }

  // Delete an account
  Future<void> deleteAccount(String id) async {
    final db = await database;

    // Check if account has transactions
    final transactionCount = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM transactions WHERE accountId = ? OR toAccountId = ?',
      [id, id],
    ));

    if (transactionCount! > 0) {
      throw Exception('Cannot delete account with associated transactions');
    }

    await db.delete(
      'accounts',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Update account balance
  Future<void> updateAccountBalance(String accountId, double newBalance) async {
    final db = await database;
    await db.update(
      'accounts',
      {'balance': newBalance, 'updatedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [accountId],
    );
  }

  // TRANSFERS

  // Create a transfer between accounts
  Future<bool> createTransfer({
    required String fromAccountId,
    required String toAccountId,
    required double amount,
    required String title,
    required String userId,
    String? notes,
  }) async {
    final db = await database;

    try {
      // Begin transaction
      return await db.transaction((txn) async {
        // Get source and destination accounts using the transaction object
        final sourceAccount = await getAccountById(fromAccountId, txn: txn);
        final destAccount = await getAccountById(toAccountId, txn: txn);

        if (sourceAccount == null || destAccount == null) {
          throw Exception('Source or destination account not found');
        }

        // Check if there's enough balance in the source account
        if (sourceAccount.balance < amount) {
          throw Exception('Insufficient balance in source account');
        }

        // Create the transfer transaction
        final transferTx = TransactionModel.createTransfer(
          title: title,
          amount: amount,
          date: DateTime.now(),
          userId: userId,
          fromAccountId: fromAccountId,
          toAccountId: toAccountId,
          notes: notes,
        );

        // Insert the transfer transaction
        await txn.insert(
          'transactions',
          transferTx.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // Update source account balance
        await txn.update(
          'accounts',
          {
            'balance': sourceAccount.balance - amount,
            'updatedAt': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [fromAccountId],
        );

        // Update destination account balance
        await txn.update(
          'accounts',
          {
            'balance': destAccount.balance + amount,
            'updatedAt': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [toAccountId],
        );

        return true;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error creating transfer: $e');
      }
      return false;
    }
  }

  // Get transfers for a user
  Future<List<TransactionModel>> getTransfers(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'userId = ? AND type = ?',
      whereArgs: [userId, 'transfer'],
      orderBy: 'date DESC',
    );

    return List.generate(maps.length, (i) {
      return TransactionModel.fromMap(maps[i]);
    });
  }
}
