import 'package:flutter/material.dart';

class CategoryModel {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final bool isIncome;
  final bool isDefault;
  final String? createdBy; // For premium multi-user functionality

  // Constructor for category model
  CategoryModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.backgroundColor,
    this.isIncome = false, // Default to expense
    this.isDefault = false, // Default to user-created (not default)
    this.createdBy,
  });

  // Create a copy with modified properties
  CategoryModel copyWith({
    String? id,
    String? name,
    IconData? icon,
    Color? color,
    Color? backgroundColor,
    bool? isIncome,
    bool? isDefault,
    String? createdBy,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      isIncome: isIncome ?? this.isIncome,
      isDefault: isDefault ?? this.isDefault,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  // Convert to map for storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'iconCodePoint': icon.codePoint,
      'iconFontFamily': icon.fontFamily,
      'colorValue': color.value,
      'backgroundColorValue': backgroundColor.value,
      'isIncome': isIncome,
      'isDefault': isDefault,
      'createdBy': createdBy,
    };
  }

  // Create from map
  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'],
      name: map['name'],
      icon: IconData(
        map['iconCodePoint'],
        fontFamily: map['iconFontFamily'],
      ),
      color: Color(map['colorValue']),
      backgroundColor: Color(map['backgroundColorValue']),
      isIncome: map['isIncome'] ?? false,
      isDefault: map['isDefault'] ?? false,
      createdBy: map['createdBy'],
    );
  }

  // Default expense categories
  static List<CategoryModel> defaultExpenseCategories() {
    return [
      CategoryModel(
        id: 'food',
        name: 'Food',
        icon: Icons.restaurant,
        color: Colors.orange,
        backgroundColor: const Color(0xFFFFF3E0),
        isDefault: true,
      ),
      CategoryModel(
        id: 'shopping',
        name: 'Shopping',
        icon: Icons.shopping_cart,
        color: Colors.pink,
        backgroundColor: const Color(0xFFFCE4EC),
        isDefault: true,
      ),
      CategoryModel(
        id: 'phone',
        name: 'Phone',
        icon: Icons.phone_android,
        color: Colors.blue,
        backgroundColor: const Color(0xFFE3F2FD),
        isDefault: true,
      ),
      CategoryModel(
        id: 'entertainment',
        name: 'Entertainment',
        icon: Icons.sports_esports,
        color: Colors.purple,
        backgroundColor: const Color(0xFFF3E5F5),
        isDefault: true,
      ),
      CategoryModel(
        id: 'education',
        name: 'Education',
        icon: Icons.menu_book,
        color: Colors.indigo,
        backgroundColor: const Color(0xFFE8EAF6),
        isDefault: true,
      ),
      CategoryModel(
        id: 'beauty',
        name: 'Beauty',
        icon: Icons.face,
        color: Colors.pink.shade300,
        backgroundColor: const Color(0xFFFCE4EC).withOpacity(0.7),
        isDefault: true,
      ),
      CategoryModel(
        id: 'sports',
        name: 'Sports',
        icon: Icons.fitness_center,
        color: Colors.cyan,
        backgroundColor: const Color(0xFFE0F7FA),
        isDefault: true,
      ),
      CategoryModel(
        id: 'social',
        name: 'Social',
        icon: Icons.people,
        color: Colors.amber,
        backgroundColor: const Color(0xFFFFF8E1),
        isDefault: true,
      ),
      CategoryModel(
        id: 'transport',
        name: 'Transportation',
        icon: Icons.directions_bus,
        color: Colors.blue.shade700,
        backgroundColor: const Color(0xFFE3F2FD).withOpacity(0.7),
        isDefault: true,
      ),
      CategoryModel(
        id: 'clothing',
        name: 'Clothing',
        icon: Icons.checkroom,
        color: Colors.teal,
        backgroundColor: const Color(0xFFE0F2F1),
        isDefault: true,
      ),
      CategoryModel(
        id: 'car',
        name: 'Car',
        icon: Icons.directions_car,
        color: Colors.grey.shade700,
        backgroundColor: Colors.grey.shade200,
        isDefault: true,
      ),
      CategoryModel(
        id: 'alcohol',
        name: 'Alcohol',
        icon: Icons.local_bar,
        color: Colors.deepPurple,
        backgroundColor: const Color(0xFFEDE7F6),
        isDefault: true,
      ),
      CategoryModel(
        id: 'cigarettes',
        name: 'Cigarettes',
        icon: Icons.smoking_rooms,
        color: Colors.brown,
        backgroundColor: const Color(0xFFEFEBE9),
        isDefault: true,
      ),
      CategoryModel(
        id: 'electronics',
        name: 'Electronics',
        icon: Icons.devices,
        color: Colors.indigo.shade300,
        backgroundColor: const Color(0xFFE8EAF6).withOpacity(0.7),
        isDefault: true,
      ),
      CategoryModel(
        id: 'travel',
        name: 'Travel',
        icon: Icons.flight,
        color: Colors.lightBlue,
        backgroundColor: const Color(0xFFE1F5FE),
        isDefault: true,
      ),
      CategoryModel(
        id: 'health',
        name: 'Health',
        icon: Icons.medical_services,
        color: Colors.green,
        backgroundColor: const Color(0xFFE8F5E9),
        isDefault: true,
      ),
      CategoryModel(
        id: 'pets',
        name: 'Pets',
        icon: Icons.pets,
        color: Colors.brown.shade400,
        backgroundColor: const Color(0xFFEFEBE9).withOpacity(0.7),
        isDefault: true,
      ),
      CategoryModel(
        id: 'repairs',
        name: 'Repairs',
        icon: Icons.handyman,
        color: Colors.blueGrey,
        backgroundColor: Colors.blueGrey.shade100,
        isDefault: true,
      ),
      CategoryModel(
        id: 'housing',
        name: 'Housing',
        icon: Icons.home,
        color: Colors.red.shade400,
        backgroundColor: const Color(0xFFFFEBEE).withOpacity(0.7),
        isDefault: true,
      ),
      CategoryModel(
        id: 'bills',
        name: 'Bills',
        icon: Icons.receipt,
        color: Colors.red,
        backgroundColor: const Color(0xFFFFEBEE),
        isDefault: true,
      ),
      CategoryModel(
        id: 'gifts',
        name: 'Gifts',
        icon: Icons.card_giftcard,
        color: Colors.pink,
        backgroundColor: const Color(0xFFFCE4EC),
        isDefault: true,
      ),
      CategoryModel(
        id: 'donations',
        name: 'Donations',
        icon: Icons.favorite,
        color: Colors.red.shade300,
        backgroundColor: const Color(0xFFFFEBEE).withOpacity(0.7),
        isDefault: true,
      ),
      CategoryModel(
        id: 'lottery',
        name: 'Lottery',
        icon: Icons.monetization_on,
        color: Colors.amber.shade700,
        backgroundColor: const Color(0xFFFFF8E1).withOpacity(0.7),
        isDefault: true,
      ),
      CategoryModel(
        id: 'snacks',
        name: 'Snacks',
        icon: Icons.bakery_dining,
        color: Colors.orange.shade300,
        backgroundColor: const Color(0xFFFFF3E0).withOpacity(0.7),
        isDefault: true,
      ),
      CategoryModel(
        id: 'kids',
        name: 'Kids',
        icon: Icons.child_care,
        color: Colors.lightBlue.shade300,
        backgroundColor: const Color(0xFFE1F5FE).withOpacity(0.7),
        isDefault: true,
      ),
      CategoryModel(
        id: 'vegetables',
        name: 'Vegetables',
        icon: Icons.eco,
        color: Colors.green.shade600,
        backgroundColor: const Color(0xFFE8F5E9).withOpacity(0.7),
        isDefault: true,
      ),
      CategoryModel(
        id: 'fruits',
        name: 'Fruits',
        icon: Icons.emoji_food_beverage,
        color: Colors.green.shade400,
        backgroundColor: const Color(0xFFE8F5E9).withOpacity(0.8),
        isDefault: true,
      ),
      CategoryModel(
        id: 'other_expense',
        name: 'Other',
        icon: Icons.more_horiz,
        color: Colors.grey,
        backgroundColor: Colors.grey.shade100,
        isDefault: true,
      ),
    ];
  }

  // Default income categories
  static List<CategoryModel> defaultIncomeCategories() {
    return [
      CategoryModel(
        id: 'salary',
        name: 'Salary',
        icon: Icons.work,
        color: Colors.green,
        backgroundColor: const Color(0xFFE8F5E9),
        isIncome: true,
        isDefault: true,
      ),
      CategoryModel(
        id: 'freelance',
        name: 'Freelance',
        icon: Icons.computer,
        color: Colors.blue,
        backgroundColor: const Color(0xFFE3F2FD),
        isIncome: true,
        isDefault: true,
      ),
      CategoryModel(
        id: 'business',
        name: 'Business',
        icon: Icons.business_center,
        color: Colors.amber,
        backgroundColor: const Color(0xFFFFF8E1),
        isIncome: true,
        isDefault: true,
      ),
      CategoryModel(
        id: 'investments',
        name: 'Investments',
        icon: Icons.trending_up,
        color: Colors.green.shade700,
        backgroundColor: const Color(0xFFE8F5E9).withOpacity(0.7),
        isIncome: true,
        isDefault: true,
      ),
      CategoryModel(
        id: 'gifts_income',
        name: 'Gifts',
        icon: Icons.card_giftcard,
        color: Colors.pink,
        backgroundColor: const Color(0xFFFCE4EC),
        isIncome: true,
        isDefault: true,
      ),
      CategoryModel(
        id: 'rental',
        name: 'Rental',
        icon: Icons.home,
        color: Colors.indigo,
        backgroundColor: const Color(0xFFE8EAF6),
        isIncome: true,
        isDefault: true,
      ),
      CategoryModel(
        id: 'refunds',
        name: 'Refunds',
        icon: Icons.assignment_return,
        color: Colors.teal,
        backgroundColor: const Color(0xFFE0F2F1),
        isIncome: true,
        isDefault: true,
      ),
      CategoryModel(
        id: 'lottery_income',
        name: 'Lottery',
        icon: Icons.monetization_on,
        color: Colors.amber.shade600,
        backgroundColor: const Color(0xFFFFF8E1).withOpacity(0.8),
        isIncome: true,
        isDefault: true,
      ),
      CategoryModel(
        id: 'other_income',
        name: 'Other',
        icon: Icons.more_horiz,
        color: Colors.grey,
        backgroundColor: Colors.grey.shade100,
        isIncome: true,
        isDefault: true,
      ),
    ];
  }
}
