import 'package:uuid/uuid.dart';
import 'transaction_model.dart';

enum RecurrenceFrequency {
  daily,
  weekly,
  biweekly,
  monthly,
  quarterly,
  yearly,
}

class RecurringTransactionModel {
  final String id;
  final String title;
  final double amount;
  final String categoryId;
  final bool isExpense;
  final String userId;
  final String? notes;
  final RecurrenceFrequency frequency;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isActive;
  final int? dayOfMonth; // For monthly: which day of month to repeat (1-31)
  final int? dayOfWeek; // For weekly: which day of week (1-7, 1 is Monday)
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? metadata;

  RecurringTransactionModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.categoryId,
    required this.isExpense,
    required this.userId,
    required this.frequency,
    required this.startDate,
    this.endDate,
    required this.isActive,
    this.dayOfMonth,
    this.dayOfWeek,
    this.notes,
    required this.createdAt,
    this.updatedAt,
    this.metadata,
  });

  // Create a copy with modified properties
  RecurringTransactionModel copyWith({
    String? id,
    String? title,
    double? amount,
    String? categoryId,
    bool? isExpense,
    String? userId,
    String? notes,
    RecurrenceFrequency? frequency,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    int? dayOfMonth,
    int? dayOfWeek,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return RecurringTransactionModel(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      isExpense: isExpense ?? this.isExpense,
      userId: userId ?? this.userId,
      notes: notes ?? this.notes,
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  // Convert to map for SQLite storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'categoryId': categoryId,
      'isExpense': isExpense ? 1 : 0,
      'userId': userId,
      'notes': notes,
      'frequency': frequency.name,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'isActive': isActive ? 1 : 0,
      'dayOfMonth': dayOfMonth,
      'dayOfWeek': dayOfWeek,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  // Create from map for SQLite
  factory RecurringTransactionModel.fromMap(Map<String, dynamic> map) {
    return RecurringTransactionModel(
      id: map['id'],
      title: map['title'],
      amount: map['amount'] is int
          ? (map['amount'] as int).toDouble()
          : map['amount'],
      categoryId: map['categoryId'],
      isExpense: map['isExpense'] == 1,
      userId: map['userId'],
      notes: map['notes'],
      frequency: RecurrenceFrequency.values.firstWhere(
        (e) => e.name == map['frequency'],
        orElse: () => RecurrenceFrequency.monthly,
      ),
      startDate: DateTime.parse(map['startDate']),
      endDate: map['endDate'] != null ? DateTime.parse(map['endDate']) : null,
      isActive: map['isActive'] == 1,
      dayOfMonth: map['dayOfMonth'],
      dayOfWeek: map['dayOfWeek'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt:
          map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : null,
      metadata: null, // Handle metadata conversion if needed
    );
  }

  // Factory to create a new recurring transaction
  factory RecurringTransactionModel.create({
    required String title,
    required double amount,
    required String categoryId,
    required bool isExpense,
    required String userId,
    required RecurrenceFrequency frequency,
    required DateTime startDate,
    DateTime? endDate,
    bool isActive = true,
    int? dayOfMonth,
    int? dayOfWeek,
    String? notes,
    Map<String, dynamic>? metadata,
  }) {
    final String id = const Uuid().v4(); // Generate UUID
    final DateTime now = DateTime.now();

    return RecurringTransactionModel(
      id: id,
      title: title,
      amount: amount,
      categoryId: categoryId,
      isExpense: isExpense,
      userId: userId,
      notes: notes,
      frequency: frequency,
      startDate: startDate,
      endDate: endDate,
      isActive: isActive,
      dayOfMonth: dayOfMonth,
      dayOfWeek: dayOfWeek,
      createdAt: now,
      updatedAt: now,
      metadata: metadata,
    );
  }

  // Generate the next scheduled transaction date after a given date
  DateTime getNextOccurrence(DateTime afterDate) {
    DateTime baseDate = afterDate.isAfter(startDate)
        ? afterDate
        : startDate.subtract(const Duration(days: 1));

    switch (frequency) {
      case RecurrenceFrequency.daily:
        return baseDate.add(const Duration(days: 1));

      case RecurrenceFrequency.weekly:
        if (dayOfWeek != null) {
          // If day of week is specified, find the next occurrence of that day
          int daysUntilNextOccurrence = (dayOfWeek! - baseDate.weekday) % 7;
          if (daysUntilNextOccurrence == 0) daysUntilNextOccurrence = 7;
          return baseDate.add(Duration(days: daysUntilNextOccurrence));
        }
        return baseDate.add(const Duration(days: 7));

      case RecurrenceFrequency.biweekly:
        return baseDate.add(const Duration(days: 14));

      case RecurrenceFrequency.monthly:
        DateTime nextMonth = DateTime(baseDate.year, baseDate.month + 1, 1);
        if (dayOfMonth != null) {
          // Get the last day of the month
          DateTime lastDayOfMonth =
              DateTime(nextMonth.year, nextMonth.month + 1, 0);
          // Ensure day of month doesn't exceed the month's length
          int actualDay = dayOfMonth! > lastDayOfMonth.day
              ? lastDayOfMonth.day
              : dayOfMonth!;
          return DateTime(nextMonth.year, nextMonth.month, actualDay);
        }
        return DateTime(nextMonth.year, nextMonth.month, baseDate.day);

      case RecurrenceFrequency.quarterly:
        return DateTime(baseDate.year, baseDate.month + 3, baseDate.day);

      case RecurrenceFrequency.yearly:
        return DateTime(baseDate.year + 1, baseDate.month, baseDate.day);
    }
  }

  // Generate a transaction instance for a specific date
  TransactionModel generateTransaction(DateTime forDate) {
    // Append recurring info to notes
    String transactionNotes = notes ?? '';
    if (!transactionNotes.contains('Recurring ID:')) {
      if (transactionNotes.isNotEmpty) transactionNotes += '\n\n';
      transactionNotes += 'Recurring ID: $id (Generated automatically)';
    }

    return TransactionModel.create(
      title: title,
      amount: amount,
      date: forDate,
      categoryId: categoryId,
      isExpense: isExpense,
      userId: userId,
      notes: transactionNotes,
      metadata: {
        'recurringTransactionId': id,
        ...?metadata,
      },
    );
  }

  // Check if this recurring transaction should generate a transaction for a specific date
  bool shouldGenerateForDate(DateTime date) {
    if (!isActive) return false;
    if (date.isBefore(startDate)) return false;
    if (endDate != null && date.isAfter(endDate!)) return false;

    switch (frequency) {
      case RecurrenceFrequency.daily:
        return true;

      case RecurrenceFrequency.weekly:
        if (dayOfWeek != null) {
          return date.weekday == dayOfWeek;
        }
        return date.difference(startDate).inDays % 7 == 0;

      case RecurrenceFrequency.biweekly:
        return date.difference(startDate).inDays % 14 == 0;

      case RecurrenceFrequency.monthly:
        if (dayOfMonth != null) {
          return date.day == dayOfMonth;
        }
        return date.day == startDate.day;

      case RecurrenceFrequency.quarterly:
        if (date.day != startDate.day) return false;
        int monthDiff =
            (date.year - startDate.year) * 12 + date.month - startDate.month;
        return monthDiff % 3 == 0;

      case RecurrenceFrequency.yearly:
        return date.day == startDate.day && date.month == startDate.month;
    }
  }
}
