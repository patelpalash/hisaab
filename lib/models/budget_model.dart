import 'package:cloud_firestore/cloud_firestore.dart';

class BudgetModel {
  final String id;
  final String userId;
  final String name;
  final double amount;
  final String? categoryId; // Null means overall budget
  final DateTime startDate;
  final DateTime endDate;
  final bool isRecurring;
  final String? recurrenceType; // 'monthly', 'weekly', etc.
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Constructor for budget model
  BudgetModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.amount,
    this.categoryId,
    required this.startDate,
    required this.endDate,
    this.isRecurring = true,
    this.recurrenceType = 'monthly',
    required this.createdAt,
    this.updatedAt,
  });

  // Create a copy with modified properties
  BudgetModel copyWith({
    String? id,
    String? userId,
    String? name,
    double? amount,
    String? categoryId,
    DateTime? startDate,
    DateTime? endDate,
    bool? isRecurring,
    String? recurrenceType,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BudgetModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrenceType: recurrenceType ?? this.recurrenceType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Convert to map for storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'amount': amount,
      'categoryId': categoryId,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'isRecurring': isRecurring,
      'recurrenceType': recurrenceType,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  // Create from map
  factory BudgetModel.fromMap(Map<String, dynamic> map) {
    return BudgetModel(
      id: map['id'],
      userId: map['userId'],
      name: map['name'],
      amount: map['amount'].toDouble(),
      categoryId: map['categoryId'],
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: (map['endDate'] as Timestamp).toDate(),
      isRecurring: map['isRecurring'] ?? true,
      recurrenceType: map['recurrenceType'] ?? 'monthly',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  // Factory to create a new monthly budget
  factory BudgetModel.createMonthly({
    required String userId,
    required String name,
    required double amount,
    String? categoryId,
  }) {
    final String id = FirebaseFirestore.instance.collection('budgets').doc().id;
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
}
