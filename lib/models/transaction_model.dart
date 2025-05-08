import 'package:uuid/uuid.dart';

class TransactionModel {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final String categoryId;
  final bool isExpense;
  final String userId;
  final String? notes;
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
    required this.userId,
    this.notes,
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
    String? userId,
    String? notes,
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
      userId: userId ?? this.userId,
      notes: notes ?? this.notes,
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
      'userId': userId,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  // Create from map for SQLite
  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'],
      title: map['title'],
      amount: map['amount'] is int
          ? (map['amount'] as int).toDouble()
          : map['amount'],
      date: DateTime.parse(map['date']),
      categoryId: map['categoryId'],
      isExpense: map['isExpense'] == 1,
      userId: map['userId'],
      notes: map['notes'],
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
      categoryId: categoryId,
      isExpense: isExpense,
      userId: userId,
      notes: notes,
      metadata: metadata,
      createdAt: now,
      updatedAt: now,
    );
  }
}
