import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/transaction_model.dart';
import '../../models/category_model.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/category_provider.dart';
import 'transaction_detail_screen.dart';

class TransactionsListScreen extends StatefulWidget {
  const TransactionsListScreen({Key? key}) : super(key: key);

  @override
  State<TransactionsListScreen> createState() => _TransactionsListScreenState();
}

class _TransactionsListScreenState extends State<TransactionsListScreen> {
  String _searchQuery = '';
  bool _showExpenses = true;
  bool _showIncome = true;
  DateTime? _startDate;
  DateTime? _endDate;

  final TextEditingController _searchController = TextEditingController();
  final Color primaryColor = const Color(0xFF6C63FF);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Format currency
  String _formatCurrency(double amount) {
    return '₹${NumberFormat('#,##0.00').format(amount)}';
  }

  @override
  Widget build(BuildContext context) {
    final transactionProvider = Provider.of<TransactionProvider>(context);
    final categoryProvider = Provider.of<CategoryProvider>(context);

    // Get all transactions and apply filters
    List<TransactionModel> allTransactions = transactionProvider.transactions;

    // Apply filters
    List<TransactionModel> filteredTransactions =
        allTransactions.where((transaction) {
      // Filter by type (expense/income)
      if (!_showExpenses && transaction.isExpense) return false;
      if (!_showIncome && !transaction.isExpense) return false;

      // Filter by date range
      if (_startDate != null && transaction.date.isBefore(_startDate!))
        return false;
      if (_endDate != null &&
          transaction.date.isAfter(_endDate!.add(const Duration(days: 1))))
        return false;

      // Search by title or notes
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final title = transaction.title.toLowerCase();
        final notes = transaction.notes?.toLowerCase() ?? '';

        if (!title.contains(query) && !notes.contains(query)) {
          // If not matched title or notes, check category name
          final category =
              categoryProvider.getCategoryById(transaction.categoryId);
          if (category == null ||
              !category.name.toLowerCase().contains(query)) {
            return false;
          }
        }
      }

      return true;
    }).toList();

    // Sort by date (newest first)
    filteredTransactions.sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text('All Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search transactions...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                FilterChip(
                  label: Text('Expenses'),
                  selected: _showExpenses,
                  onSelected: (selected) {
                    setState(() {
                      _showExpenses = selected;
                    });
                  },
                  selectedColor: Colors.red.withOpacity(0.2),
                  checkmarkColor: Colors.red,
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text('Income'),
                  selected: _showIncome,
                  onSelected: (selected) {
                    setState(() {
                      _showIncome = selected;
                    });
                  },
                  selectedColor: Colors.green.withOpacity(0.2),
                  checkmarkColor: Colors.green,
                ),
                const SizedBox(width: 8),
                if (_startDate != null && _endDate != null)
                  Chip(
                    label: Text(
                      '${DateFormat('MMM d').format(_startDate!)} - ${DateFormat('MMM d').format(_endDate!)}',
                      style: TextStyle(fontSize: 12),
                    ),
                    deleteIcon: Icon(Icons.close, size: 18),
                    onDeleted: () {
                      setState(() {
                        _startDate = null;
                        _endDate = null;
                      });
                    },
                  ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Transactions list
          Expanded(
            child: filteredTransactions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'No transactions found',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (_searchQuery.isNotEmpty ||
                            !_showExpenses ||
                            !_showIncome ||
                            _startDate != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              'Try changing your filters',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: filteredTransactions.length,
                    itemBuilder: (context, index) {
                      final transaction = filteredTransactions[index];
                      final category = categoryProvider
                          .getCategoryById(transaction.categoryId);

                      // Group transactions by date
                      final bool showDateHeader = index == 0 ||
                          !isSameDay(filteredTransactions[index].date,
                              filteredTransactions[index - 1].date);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showDateHeader)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                              child: Text(
                                DateFormat('EEEE, MMMM d, y')
                                    .format(transaction.date),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          _buildTransactionItem(context, transaction, category),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // Check if two dates are the same day
  bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  // Transaction item widget
  Widget _buildTransactionItem(BuildContext context,
      TransactionModel transaction, CategoryModel? category) {
    // Default icon and colors for transaction if category is not found
    IconData icon =
        transaction.isExpense ? Icons.arrow_upward : Icons.arrow_downward;
    Color iconColor = transaction.isExpense ? Colors.red : Colors.green;
    Color backgroundColor = transaction.isExpense
        ? Colors.red.withOpacity(0.1)
        : Colors.green.withOpacity(0.1);

    // If category exists, use its icon and colors
    if (category != null) {
      icon = category.icon;
      iconColor = category.color;
      backgroundColor = category.backgroundColor;
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                TransactionDetailScreen(transaction: transaction),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Category icon with background
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: iconColor,
              ),
            ),
            const SizedBox(width: 16),

            // Transaction details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  if (transaction.notes != null &&
                      transaction.notes!.isNotEmpty)
                    Text(
                      transaction.notes!,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (transaction.notes == null || transaction.notes!.isEmpty)
                    Text(
                      DateFormat('h:mm a').format(transaction.date),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ),

            // Amount
            Text(
              transaction.isExpense
                  ? '- ${_formatCurrency(transaction.amount)}'
                  : '+ ${_formatCurrency(transaction.amount)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: transaction.isExpense ? Colors.red : Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Show filter dialog for date range selection
  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Filter Transactions'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Select date range:'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _startDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() {
                          _startDate = picked;
                          if (_endDate == null ||
                              _endDate!.isBefore(_startDate!)) {
                            _endDate = _startDate;
                          }
                        });
                      }
                      Navigator.pop(context);
                    },
                    child: Text('Start Date'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _endDate ?? DateTime.now(),
                        firstDate: _startDate ?? DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() {
                          _endDate = picked;
                        });
                      }
                      Navigator.pop(context);
                    },
                    child: Text('End Date'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      final now = DateTime.now();

                      // Last 7 days
                      _startDate = DateTime(now.year, now.month, now.day - 6);
                      _endDate = DateTime(now.year, now.month, now.day);
                    });
                    Navigator.pop(context);
                  },
                  child: Text('Last 7 days'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      final now = DateTime.now();

                      // This month
                      _startDate = DateTime(now.year, now.month, 1);
                      _endDate = DateTime(now.year, now.month + 1, 0);
                    });
                    Navigator.pop(context);
                  },
                  child: Text('This Month'),
                ),
              ],
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _startDate = null;
                  _endDate = null;
                });
                Navigator.pop(context);
              },
              child: Text('Clear Filters'),
            ),
          ],
        ),
      ),
    );
  }
}
