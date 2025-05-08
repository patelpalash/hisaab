import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/budget_model.dart';
import '../../models/category_model.dart';
import '../../models/transaction_model.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/category_provider.dart';
import 'custom_pie_chart.dart';

class BudgetAnalyticsScreen extends StatefulWidget {
  final BudgetModel budget;

  const BudgetAnalyticsScreen({
    Key? key,
    required this.budget,
  }) : super(key: key);

  @override
  State<BudgetAnalyticsScreen> createState() => _BudgetAnalyticsScreenState();
}

class _BudgetAnalyticsScreenState extends State<BudgetAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late DateTime _selectedMonth;
  final Color primaryColor = const Color(0xFF6C63FF);
  Map<String, double> categoryTotals = {};
  double totalSpent = 0;
  List<TransactionModel> _filteredTransactions = [];
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _selectedMonth = widget.budget.startDate;

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _loadTransactions();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Format currency
  String _formatCurrency(double amount) {
    return '₹${NumberFormat('#,##0.00').format(amount)}';
  }

  void _loadTransactions() {
    setState(() {
      _isLoading = true;
    });

    // Get transactions for the selected month
    final transactionProvider =
        Provider.of<TransactionProvider>(context, listen: false);
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);

    // Get all transactions for this period
    _filteredTransactions = transactionProvider.transactions.where((t) {
      // Filter for selected month
      return t.isExpense &&
          t.date.isAfter(widget.budget.startDate) &&
          t.date.isBefore(widget.budget.endDate.add(const Duration(days: 1)));
    }).toList();

    // Calculate category totals
    categoryTotals = {};

    for (var transaction in _filteredTransactions) {
      final category = categoryProvider.getCategoryById(transaction.categoryId);
      final categoryName = category?.name ?? 'Uncategorized';

      if (categoryTotals.containsKey(categoryName)) {
        categoryTotals[categoryName] =
            (categoryTotals[categoryName] ?? 0) + transaction.amount;
      } else {
        categoryTotals[categoryName] = transaction.amount;
      }
    }

    // Calculate total spent
    totalSpent =
        _filteredTransactions.fold<double>(0, (sum, t) => sum + t.amount);

    setState(() {
      _isLoading = false;
    });

    // Start animation after data is loaded
    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final categoryProvider = Provider.of<CategoryProvider>(context);
    final String monthYear = DateFormat('MMMM yyyy').format(_selectedMonth);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text('Total Expense'),
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Month selector with modern design
                  _buildMonthSelector(monthYear),

                  // Expense summary with budget progress
                  _buildExpenseSummary(),

                  // Analytics header with View All button
                  _buildAnalyticsHeader(),

                  // Animated pie chart
                  AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _animation.value,
                        child: child,
                      );
                    },
                    child: _buildPieChart(categoryProvider),
                  ),

                  // Category details list
                  AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _animation.value,
                        child: child,
                      );
                    },
                    child: _buildCategoryDetails(categoryProvider),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildMonthSelector(String monthYear) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            monthYear,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 28),
                onPressed: () {
                  // Switch to previous month
                  _switchMonth(-1);
                },
                color: Colors.black54,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 28),
                onPressed: () {
                  // Switch to next month
                  _switchMonth(1);
                },
                color: Colors.black54,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _switchMonth(int monthDelta) {
    setState(() {
      if (monthDelta < 0) {
        // Previous month
        _selectedMonth = DateTime(
          _selectedMonth.year,
          _selectedMonth.month - 1,
          1,
        );
      } else {
        // Next month
        _selectedMonth = DateTime(
          _selectedMonth.year,
          _selectedMonth.month + 1,
          1,
        );
      }
      // Reload transactions for the new month
      _loadTransactions();
    });
  }

  Widget _buildExpenseSummary() {
    // Calculate budget percentage
    final double budgetPercentage =
        (totalSpent / widget.budget.amount * 100).clamp(0, 100);
    final double remainingPercentage = 100 - budgetPercentage;

    // Format the amount with the currency symbol in orange
    final amountString = _formatCurrency(totalSpent);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              children: [
                const TextSpan(
                  text: 'You have Spend ',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                  ),
                ),
                TextSpan(
                  text: amountString,
                  style: const TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const TextSpan(
                  text: ' this month.',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Modern progress bar
          Container(
            height: 10,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              children: [
                // Filled portion
                AnimatedContainer(
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeInOut,
                  width: MediaQuery.of(context).size.width *
                      (budgetPercentage / 100) *
                      0.78, // Account for padding
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Percentage indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${budgetPercentage.toStringAsFixed(2)}%',
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${remainingPercentage.toStringAsFixed(2)}%',
                style: TextStyle(
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsHeader() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Analytics',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          TextButton(
            onPressed: () {
              // View all analytics
            },
            child: Text(
              'View All',
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(CategoryProvider categoryProvider) {
    if (categoryTotals.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No expense data to display',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ),
      );
    }

    // Generate pie chart data
    List<PieChartSection> sections = [];

    // Define vibrant colors for the chart sections
    // Using a more modern color palette
    List<Color> sectionColors = [
      const Color(0xFFFF5252), // Vibrant red
      const Color(0xFFFF9800), // Orange
      const Color(0xFF6C63FF), // Purple (primary)
      const Color(0xFF00BCD4), // Cyan
      const Color(0xFF4CAF50), // Green
    ];

    // Sort categories by amount (descending)
    List<MapEntry<String, double>> sortedEntries = categoryTotals.entries
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Generate pie sections
    int colorIndex = 0;
    for (var entry in sortedEntries) {
      final categoryName = entry.key;
      final amount = entry.value;

      // Find category for color reference
      CategoryModel? category;
      for (var transaction in _filteredTransactions) {
        final cat = categoryProvider.getCategoryById(transaction.categoryId);
        if (cat != null && cat.name == categoryName) {
          category = cat;
          break;
        }
      }

      // Use category color or fallback to predefined colors
      final color =
          category?.color ?? sectionColors[colorIndex % sectionColors.length];
      colorIndex++;

      sections.add(
        PieChartSection(
          title: categoryName,
          value: amount,
          color: color,
        ),
      );
    }

    return Container(
      height: 300,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Center(
        child: ScaleTransition(
          scale: _animation,
          child: CustomPieChart(
            sections: sections,
            radius: 120.0,
            centerSpaceRadius: 40.0,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryDetails(CategoryProvider categoryProvider) {
    // Sort categories by amount (descending)
    List<MapEntry<String, double>> sortedEntries = categoryTotals.entries
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: sortedEntries.map((entry) {
          final categoryName = entry.key;
          final amount = entry.value;
          final double percentage =
              totalSpent > 0 ? (amount / totalSpent * 100).toDouble() : 0.0;

          // Find category for icon/color
          CategoryModel? category;
          for (var transaction in _filteredTransactions) {
            final cat =
                categoryProvider.getCategoryById(transaction.categoryId);
            if (cat != null && cat.name == categoryName) {
              category = cat;
              break;
            }
          }

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.shade100,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                // Category icon in a stylish container
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: category?.color?.withOpacity(0.1) ??
                        Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    category?.icon ?? Icons.category,
                    color: category?.color ?? Colors.grey,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),

                // Category name and amount
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        categoryName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatCurrency(amount),
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                // Percentage indicator with bold styling
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: category?.color ?? Colors.grey,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${percentage.round()}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
