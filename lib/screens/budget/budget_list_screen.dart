import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/category_provider.dart';
import '../../models/budget_model.dart';
import '../../models/category_model.dart';
import '../../models/transaction_model.dart';
import '../../screens/analytics/budget_analytics_screen.dart';
import 'add_budget_screen.dart';

class BudgetListScreen extends StatefulWidget {
  const BudgetListScreen({Key? key}) : super(key: key);

  @override
  State<BudgetListScreen> createState() => _BudgetListScreenState();
}

class _BudgetListScreenState extends State<BudgetListScreen> {
  bool _isCurrentMonth = true;
  final Color primaryColor = const Color(0xFF6C63FF);

  @override
  void initState() {
    super.initState();
    // Initialize budgets with current user data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.isAuthenticated) {
        final userId = authProvider.user.uid;
        Provider.of<BudgetProvider>(context, listen: false).initBudgets(userId);
      }
    });
  }

  // Format currency
  String _formatCurrency(double amount) {
    return '₹${NumberFormat('#,##0.00').format(amount)}';
  }

  @override
  Widget build(BuildContext context) {
    // Access providers
    final budgetProvider = Provider.of<BudgetProvider>(context);
    final transactionProvider = Provider.of<TransactionProvider>(context);
    final categoryProvider = Provider.of<CategoryProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    // Get budgets based on filter
    final List<BudgetModel> budgets = _isCurrentMonth
        ? budgetProvider.currentMonthBudgets
        : budgetProvider.budgets;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text('Budgets'),
        actions: [
          // Filter toggle
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              setState(() {
                _isCurrentMonth = !_isCurrentMonth;
              });
            },
            tooltip: _isCurrentMonth
                ? 'Showing current month'
                : 'Showing all budgets',
          ),
        ],
      ),
      body: budgetProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Summary card
                _buildSummaryCard(budgets, transactionProvider.transactions),

                // Budgets list
                Expanded(
                  child: budgets.isEmpty
                      ? _buildEmptyState()
                      : _buildBudgetsList(
                          budgets: budgets,
                          transactions: transactionProvider.transactions,
                          categoryProvider: categoryProvider,
                          budgetProvider: budgetProvider,
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryColor,
        onPressed: () {
          // Navigate to add budget screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddBudgetScreen(
                userId: authProvider.user.uid,
              ),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSummaryCard(
      List<BudgetModel> budgets, List<TransactionModel> transactions) {
    // Calculate total budget amount
    final totalBudget =
        budgets.fold<double>(0, (sum, budget) => sum + budget.amount);

    // Calculate total spent this month
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    final monthlyTransactions = transactions.where((t) {
      return t.isExpense &&
          t.date.isAfter(startOfMonth) &&
          t.date.isBefore(endOfMonth.add(const Duration(days: 1)));
    }).toList();

    final totalSpent = monthlyTransactions.fold<double>(
        0, (sum, transaction) => sum + transaction.amount);

    // Calculate remaining budget
    final remaining = totalBudget - totalSpent;
    final progress =
        totalBudget > 0 ? (totalSpent / totalBudget).clamp(0.0, 1.0) : 0.0;

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Monthly Overview',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  DateFormat('MMMM yyyy').format(DateTime.now()),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress > 0.9 ? Colors.red : primaryColor,
              ),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryItem(
                  'Total Budget',
                  _formatCurrency(totalBudget),
                  Icons.account_balance_wallet,
                  primaryColor,
                ),
                _buildSummaryItem(
                  'Spent',
                  _formatCurrency(totalSpent),
                  Icons.shopping_cart,
                  Colors.orange,
                ),
                _buildSummaryItem(
                  'Remaining',
                  _formatCurrency(remaining),
                  Icons.savings,
                  remaining >= 0 ? Colors.green : Colors.red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
      String title, String value, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.savings,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No budgets found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to create a budget',
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetsList({
    required List<BudgetModel> budgets,
    required List<TransactionModel> transactions,
    required CategoryProvider categoryProvider,
    required BudgetProvider budgetProvider,
  }) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: budgets.length,
      itemBuilder: (context, index) {
        final budget = budgets[index];

        // Get the category if this is a category budget
        CategoryModel? category;
        if (budget.categoryId != null) {
          category = categoryProvider.getCategoryById(budget.categoryId!);
        }

        // Calculate progress
        final progress = budgetProvider.getBudgetProgress(budget, transactions);

        // Calculate amount spent
        final spent = transactions.where((t) {
          final inDateRange = t.date.isAfter(budget.startDate) &&
              t.date.isBefore(budget.endDate.add(const Duration(days: 1)));

          final matchesCategory = budget.categoryId != null
              ? t.categoryId == budget.categoryId
              : true;

          return t.isExpense && inDateRange && matchesCategory;
        }).fold<double>(0, (sum, t) => sum + t.amount);

        final remaining = budget.amount - spent;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () {
              // Navigate to budget analytics screen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BudgetAnalyticsScreen(budget: budget),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (category != null) ...[
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: category.backgroundColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            category.icon,
                            color: category.color,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.account_balance_wallet,
                            color: primaryColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              budget.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              category != null
                                  ? category.name
                                  : 'Overall Budget',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatCurrency(budget.amount),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '${DateFormat('MMM d').format(budget.startDate)} - ${DateFormat('MMM d').format(budget.endDate)}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress < 0.7
                          ? Colors.green
                          : progress < 0.9
                              ? Colors.orange
                              : Colors.red,
                    ),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Spent: ${_formatCurrency(spent)}',
                        style: const TextStyle(
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'Remaining: ${_formatCurrency(remaining)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: remaining >= 0 ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
