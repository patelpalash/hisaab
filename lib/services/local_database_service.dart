import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:async';
import '../models/user_model.dart';
import '../models/transaction_model.dart';
import '../models/category_model.dart';
import '../models/budget_model.dart';
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
      version: 1,
      onCreate: _createDb,
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
      {
        'id': budget.id,
        'userId': budget.userId,
        'name': budget.name,
        'amount': budget.amount,
        'categoryId': budget.categoryId,
        'startDate': budget.startDate.toIso8601String(),
        'endDate': budget.endDate.toIso8601String(),
        'isRecurring': budget.isRecurring ? 1 : 0,
        'recurrenceType': budget.recurrenceType,
        'createdAt': budget.createdAt.toIso8601String(),
        'updatedAt': budget.updatedAt?.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return budget.id;
  }

  Future<void> updateBudget(BudgetModel budget) async {
    final db = await database;
    await db.update(
      'budgets',
      {
        'userId': budget.userId,
        'name': budget.name,
        'amount': budget.amount,
        'categoryId': budget.categoryId,
        'startDate': budget.startDate.toIso8601String(),
        'endDate': budget.endDate.toIso8601String(),
        'isRecurring': budget.isRecurring ? 1 : 0,
        'recurrenceType': budget.recurrenceType,
        'updatedAt': DateTime.now().toIso8601String(),
      },
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
      return BudgetModel(
        id: maps[i]['id'],
        userId: maps[i]['userId'],
        name: maps[i]['name'],
        amount: maps[i]['amount'],
        categoryId: maps[i]['categoryId'],
        startDate: DateTime.parse(maps[i]['startDate']),
        endDate: DateTime.parse(maps[i]['endDate']),
        isRecurring: maps[i]['isRecurring'] == 1,
        recurrenceType: maps[i]['recurrenceType'],
        createdAt: DateTime.parse(maps[i]['createdAt']),
        updatedAt: maps[i]['updatedAt'] != null
            ? DateTime.parse(maps[i]['updatedAt'])
            : null,
      );
    });
  }

  Future<List<BudgetModel>> getCurrentMonthBudgets(String userId) async {
    final db = await database;
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1).toIso8601String();
    final endOfMonth = DateTime(now.year, now.month + 1, 0).toIso8601String();

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT * FROM budgets 
      WHERE userId = ? 
      AND startDate <= ? 
      AND endDate >= ?
    ''', [userId, endOfMonth, startOfMonth]);

    return List.generate(maps.length, (i) {
      return BudgetModel(
        id: maps[i]['id'],
        userId: maps[i]['userId'],
        name: maps[i]['name'],
        amount: maps[i]['amount'],
        categoryId: maps[i]['categoryId'],
        startDate: DateTime.parse(maps[i]['startDate']),
        endDate: DateTime.parse(maps[i]['endDate']),
        isRecurring: maps[i]['isRecurring'] == 1,
        recurrenceType: maps[i]['recurrenceType'],
        createdAt: DateTime.parse(maps[i]['createdAt']),
        updatedAt: maps[i]['updatedAt'] != null
            ? DateTime.parse(maps[i]['updatedAt'])
            : null,
      );
    });
  }
}
