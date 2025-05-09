import 'package:uuid/uuid.dart';

enum TransactionType { expense, income, transfer }

class TransactionModel {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final String categoryId;
  final bool isExpense;
  final TransactionType type;
  final String userId;
  final String? notes;
  final String? accountId;
  final String? toAccountId;
  final Map<String, dynamic>?
      metadata; // For future features like attachments, tags, etc.
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Constructor for transaction model
  TransactionModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.categoryId,
    required this.isExpense,
    required this.type,
    required this.userId,
    this.notes,
    this.accountId,
    this.toAccountId,
    this.metadata,
    required this.createdAt,
    this.updatedAt,
  });

  // Create a copy with modified properties
  TransactionModel copyWith({
    String? id,
    String? title,
    double? amount,
    DateTime? date,
    String? categoryId,
    bool? isExpense,
    TransactionType? type,
    String? userId,
    String? notes,
    String? accountId,
    String? toAccountId,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      categoryId: categoryId ?? this.categoryId,
      isExpense: isExpense ?? this.isExpense,
      type: type ?? this.type,
      userId: userId ?? this.userId,
      notes: notes ?? this.notes,
      accountId: accountId ?? this.accountId,
      toAccountId: toAccountId ?? this.toAccountId,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Convert to map for SQLite storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'categoryId': categoryId,
      'isExpense': isExpense ? 1 : 0,
      'type': type.toString().split('.').last,
      'userId': userId,
      'notes': notes,
      'accountId': accountId,
      'toAccountId': toAccountId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  // Create from map for SQLite
  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    // Handle backward compatibility by inferring transaction type if not present
    TransactionType inferredType;
    if (map.containsKey('type') && map['type'] != null) {
      inferredType = TransactionType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
        orElse: () => map['isExpense'] == 1
            ? TransactionType.expense
            : TransactionType.income,
      );
    } else {
      inferredType = map['isExpense'] == 1
          ? TransactionType.expense
          : TransactionType.income;
    }

    return TransactionModel(
      id: map['id'],
      title: map['title'],
      amount: map['amount'] is int
          ? (map['amount'] as int).toDouble()
          : map['amount'],
      date: DateTime.parse(map['date']),
      categoryId: map['categoryId'],
      isExpense: map['isExpense'] == 1,
      type: inferredType,
      userId: map['userId'],
      notes: map['notes'],
      accountId: map['accountId'],
      toAccountId: map['toAccountId'],
      metadata: null, // Handle metadata conversion if needed
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt:
          map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : null,
    );
  }

  // Factory to create a new transaction
  factory TransactionModel.create({
    required String title,
    required double amount,
    required DateTime date,
    required String categoryId,
    required bool isExpense,
    required String userId,
    TransactionType? type,
    String? notes,
    String? accountId,
    String? toAccountId,
    Map<String, dynamic>? metadata,
  }) {
    final String id = const Uuid().v4(); // Generate UUID
    final DateTime now = DateTime.now();

    // Infer transaction type if not provided
    final transactionType =
        type ?? (isExpense ? TransactionType.expense : TransactionType.income);

    return TransactionModel(
      id: id,
      title: title,
      amount: amount,
      date: date,
      categoryId: categoryId,
      isExpense: isExpense,
      type: transactionType,
      userId: userId,
      notes: notes,
      accountId: accountId,
      toAccountId: toAccountId,
      metadata: metadata,
      createdAt: now,
      updatedAt: now,
    );
  }

  // Factory to create a transfer transaction
  factory TransactionModel.createTransfer({
    required String title,
    required double amount,
    required DateTime date,
    required String userId,
    required String fromAccountId,
    required String toAccountId,
    String? categoryId,
    String? notes,
    Map<String, dynamic>? metadata,
  }) {
    final String id = const Uuid().v4(); // Generate UUID
    final DateTime now = DateTime.now();

    return TransactionModel(
      id: id,
      title: title,
      amount: amount,
      date: date,
      categoryId: categoryId ?? '', // Transfer may not need a category
      isExpense: false, // Transfers are neither income nor expense
      type: TransactionType.transfer,
      userId: userId,
      notes: notes,
      accountId: fromAccountId,
      toAccountId: toAccountId,
      metadata: metadata,
      createdAt: now,
      updatedAt: now,
    );
  }

  // Check if the transaction is a transfer
  bool get isTransfer => type == TransactionType.transfer;
}
