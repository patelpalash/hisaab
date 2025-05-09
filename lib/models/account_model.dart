import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

enum AccountType { cash, card, savings, checking, investment, other }

class AccountModel {
  final String id;
  final String name;
  final AccountType type;
  final double balance;
  final IconData icon;
  final Color color;
  final String userId;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? metadata;

  AccountModel({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    required this.icon,
    required this.color,
    required this.userId,
    required this.createdAt,
    this.updatedAt,
    this.metadata,
  });

  // Create a copy with modified properties
  AccountModel copyWith({
    String? id,
    String? name,
    AccountType? type,
    double? balance,
    IconData? icon,
    Color? color,
    String? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return AccountModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      balance: balance ?? this.balance,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  // Convert to map for SQLite storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.toString().split('.').last,
      'balance': balance,
      'iconCodePoint': icon.codePoint,
      'iconFontFamily': icon.fontFamily,
      'colorValue': color.value,
      'userId': userId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      // Metadata would need to be serialized if needed
    };
  }

  // Create from map for SQLite
  factory AccountModel.fromMap(Map<String, dynamic> map) {
    return AccountModel(
      id: map['id'],
      name: map['name'],
      type: AccountType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
        orElse: () => AccountType.other,
      ),
      balance: map['balance'] is int
          ? (map['balance'] as int).toDouble()
          : map['balance'],
      icon: IconData(
        map['iconCodePoint'],
        fontFamily: map['iconFontFamily'],
      ),
      color: Color(map['colorValue']),
      userId: map['userId'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt:
          map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : null,
      metadata: null, // Handle metadata conversion if needed
    );
  }

  // Factory to create a new account
  factory AccountModel.create({
    required String name,
    required AccountType type,
    required double balance,
    required IconData icon,
    required Color color,
    required String userId,
    Map<String, dynamic>? metadata,
  }) {
    final String id = const Uuid().v4(); // Generate UUID
    final DateTime now = DateTime.now();

    return AccountModel(
      id: id,
      name: name,
      type: type,
      balance: balance,
      icon: icon,
      color: color,
      userId: userId,
      createdAt: now,
      updatedAt: now,
      metadata: metadata,
    );
  }

  // Default accounts for new users
  static List<AccountModel> defaultAccounts(String userId) {
    final DateTime now = DateTime.now();
    return [
      AccountModel(
        id: const Uuid().v4(),
        name: 'Cash',
        type: AccountType.cash,
        balance: 0.0,
        icon: Icons.money,
        color: Colors.green,
        userId: userId,
        createdAt: now,
        updatedAt: now,
      ),
      AccountModel(
        id: const Uuid().v4(),
        name: 'Card',
        type: AccountType.card,
        balance: 0.0,
        icon: Icons.credit_card,
        color: Colors.red,
        userId: userId,
        createdAt: now,
        updatedAt: now,
      ),
      AccountModel(
        id: const Uuid().v4(),
        name: 'Savings',
        type: AccountType.savings,
        balance: 0.0,
        icon: Icons.savings,
        color: Colors.amber,
        userId: userId,
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }
}
