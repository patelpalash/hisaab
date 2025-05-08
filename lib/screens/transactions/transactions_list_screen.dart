import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../models/transaction_model.dart';
import '../../models/category_model.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/category_provider.dart';
import 'transaction_detail_screen.dart';
import '../add_transaction_screen.dart';

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
  List<String> _selectedCategoryIds = [];

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

      // Filter by selected categories
      if (_selectedCategoryIds.isNotEmpty &&
          !_selectedCategoryIds.contains(transaction.categoryId)) {
        return false;
      }

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
                if (_selectedCategoryIds.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Chip(
                    label: Text(
                      '${_selectedCategoryIds.length} categories',
                      style: TextStyle(fontSize: 12),
                    ),
                    deleteIcon: Icon(Icons.close, size: 18),
                    onDeleted: () {
                      setState(() {
                        _selectedCategoryIds = [];
                      });
                    },
                  ),
                ],
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

    // Create the transaction card
    Widget transactionCard = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
                if (transaction.notes != null && transaction.notes!.isNotEmpty)
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
    );

    // Wrap with Slidable for swipe actions
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Slidable(
        key: Key(transaction.id),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.25,
          children: [
            SlidableAction(
              onPressed: (_) {
                _navigateToEditTransaction(context, transaction);
              },
              backgroundColor: Colors.transparent,
              foregroundColor: primaryColor,
              icon: Icons.edit_outlined,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              padding: const EdgeInsets.all(4),
              spacing: 4,
              autoClose: true,
            ),
            SlidableAction(
              onPressed: (_) {
                _confirmDelete(context, transaction);
              },
              backgroundColor: Color(0xFFF06292), // Pink shade
              foregroundColor: Colors.white,
              icon: Icons.delete_outline_rounded,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              padding: const EdgeInsets.all(4),
              spacing: 4,
              autoClose: true,
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
            borderRadius: BorderRadius.circular(16),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Material(
              color: Colors.white,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          TransactionDetailScreen(transaction: transaction),
                    ),
                  );
                },
                child: transactionCard,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Confirm delete dialog
  void _confirmDelete(BuildContext context, TransactionModel transaction) {
    final transactionProvider =
        Provider.of<TransactionProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: Text(
          'Are you sure you want to delete this ${transaction.isExpense ? 'expense' : 'income'} of ${_formatCurrency(transaction.amount)}?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              // Delete the transaction
              final success =
                  await transactionProvider.deleteTransaction(transaction.id);
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Transaction deleted')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to delete transaction')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // Show filter dialog for date range selection
  void _showFilterDialog() {
    // Store temporary filter selections
    DateTime? tempStartDate = _startDate;
    DateTime? tempEndDate = _endDate;
    bool tempShowExpenses = _showExpenses;
    bool tempShowIncome = _showIncome;
    List<String> selectedCategoryIds = List.from(_selectedCategoryIds);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'Filter Transactions',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Transaction type filters
                          Text(
                            'Transaction Type',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      tempShowExpenses = !tempShowExpenses;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: tempShowExpenses
                                          ? Colors.red.withOpacity(0.1)
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: tempShowExpenses
                                            ? Colors.red
                                            : Colors.grey.shade300,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.arrow_upward,
                                          color: tempShowExpenses
                                              ? Colors.red
                                              : Colors.grey.shade600,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Expenses',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: tempShowExpenses
                                                ? Colors.red
                                                : Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      tempShowIncome = !tempShowIncome;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: tempShowIncome
                                          ? Colors.green.withOpacity(0.1)
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: tempShowIncome
                                            ? Colors.green
                                            : Colors.grey.shade300,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.arrow_downward,
                                          color: tempShowIncome
                                              ? Colors.green
                                              : Colors.grey.shade600,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Income',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: tempShowIncome
                                                ? Colors.green
                                                : Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Date range section
                          Text(
                            'Date Range',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Quick date selectors
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildDateRangeChip(
                                  'Today',
                                  () {
                                    final now = DateTime.now();
                                    setState(() {
                                      tempStartDate = DateTime(
                                          now.year, now.month, now.day);
                                      tempEndDate = DateTime(
                                          now.year, now.month, now.day);
                                    });
                                  },
                                  isSelected:
                                      _isToday(tempStartDate, tempEndDate),
                                ),
                                const SizedBox(width: 8),
                                _buildDateRangeChip(
                                  'Last 7 days',
                                  () {
                                    final now = DateTime.now();
                                    setState(() {
                                      tempStartDate = DateTime(
                                          now.year, now.month, now.day - 6);
                                      tempEndDate = DateTime(
                                          now.year, now.month, now.day);
                                    });
                                  },
                                  isSelected:
                                      _isLast7Days(tempStartDate, tempEndDate),
                                ),
                                const SizedBox(width: 8),
                                _buildDateRangeChip(
                                  'This Month',
                                  () {
                                    final now = DateTime.now();
                                    setState(() {
                                      tempStartDate =
                                          DateTime(now.year, now.month, 1);
                                      tempEndDate =
                                          DateTime(now.year, now.month + 1, 0);
                                    });
                                  },
                                  isSelected:
                                      _isThisMonth(tempStartDate, tempEndDate),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Custom date range
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate:
                                          tempStartDate ?? DateTime.now(),
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime.now(),
                                      builder: (context, child) {
                                        return Theme(
                                          data: Theme.of(context).copyWith(
                                            colorScheme: ColorScheme.light(
                                              primary: primaryColor,
                                              onPrimary: Colors.white,
                                            ),
                                          ),
                                          child: child!,
                                        );
                                      },
                                    );
                                    if (picked != null) {
                                      setState(() {
                                        tempStartDate = picked;
                                        if (tempEndDate == null ||
                                            tempEndDate!
                                                .isBefore(tempStartDate!)) {
                                          tempEndDate = tempStartDate;
                                        }
                                      });
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12, horizontal: 16),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.calendar_today,
                                            color: primaryColor, size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            tempStartDate == null
                                                ? 'Start Date'
                                                : DateFormat('MMM dd, yyyy')
                                                    .format(tempStartDate!),
                                            style: TextStyle(
                                              color: tempStartDate == null
                                                  ? Colors.grey.shade600
                                                  : Colors.black,
                                              fontSize: 14,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: Text('to',
                                    style: TextStyle(color: Colors.grey)),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate:
                                          tempEndDate ?? DateTime.now(),
                                      firstDate:
                                          tempStartDate ?? DateTime(2020),
                                      lastDate: DateTime.now(),
                                      builder: (context, child) {
                                        return Theme(
                                          data: Theme.of(context).copyWith(
                                            colorScheme: ColorScheme.light(
                                              primary: primaryColor,
                                              onPrimary: Colors.white,
                                            ),
                                          ),
                                          child: child!,
                                        );
                                      },
                                    );
                                    if (picked != null) {
                                      setState(() {
                                        tempEndDate = picked;
                                      });
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12, horizontal: 16),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.calendar_today,
                                            color: primaryColor, size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            tempEndDate == null
                                                ? 'End Date'
                                                : DateFormat('MMM dd, yyyy')
                                                    .format(tempEndDate!),
                                            style: TextStyle(
                                              color: tempEndDate == null
                                                  ? Colors.grey.shade600
                                                  : Colors.black,
                                              fontSize: 14,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Categories section
                          Text(
                            'Categories',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 16),

                          Consumer<CategoryProvider>(
                            builder: (context, categoryProvider, _) {
                              final allCategories = [
                                ...categoryProvider.expenseCategories,
                                ...categoryProvider.incomeCategories
                              ];

                              return Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: allCategories.map((category) {
                                  final isSelected =
                                      selectedCategoryIds.contains(category.id);

                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        if (isSelected) {
                                          selectedCategoryIds
                                              .remove(category.id);
                                        } else {
                                          selectedCategoryIds.add(category.id);
                                        }
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? category.color.withOpacity(0.1)
                                            : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: isSelected
                                              ? category.color
                                              : Colors.grey.shade300,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            category.icon,
                                            color: isSelected
                                                ? category.color
                                                : Colors.grey.shade600,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            category.name,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                              color: isSelected
                                                  ? category.color
                                                  : Colors.grey.shade800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Action buttons
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade200,
                        offset: const Offset(0, -2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              tempStartDate = null;
                              tempEndDate = null;
                              tempShowExpenses = true;
                              tempShowIncome = true;
                              selectedCategoryIds.clear();
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: primaryColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text('Clear All',
                              style: TextStyle(color: primaryColor)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            this.setState(() {
                              _startDate = tempStartDate;
                              _endDate = tempEndDate;
                              _showExpenses = tempShowExpenses;
                              _showIncome = tempShowIncome;
                              _selectedCategoryIds = selectedCategoryIds;
                            });
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Apply Filters',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Helper widget for date range quick selectors
  Widget _buildDateRangeChip(String label, VoidCallback onTap,
      {bool isSelected = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isSelected ? Colors.white : Colors.grey.shade800,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // Helper methods to check date ranges
  bool _isToday(DateTime? start, DateTime? end) {
    if (start == null || end == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return start.isAtSameMomentAs(today) && end.isAtSameMomentAs(today);
  }

  bool _isLast7Days(DateTime? start, DateTime? end) {
    if (start == null || end == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sevenDaysAgo = DateTime(now.year, now.month, now.day - 6);
    return start.isAtSameMomentAs(sevenDaysAgo) && end.isAtSameMomentAs(today);
  }

  bool _isThisMonth(DateTime? start, DateTime? end) {
    if (start == null || end == null) return false;
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
    return start.isAtSameMomentAs(firstDayOfMonth) &&
        end.isAtSameMomentAs(lastDayOfMonth);
  }

  // Navigate to edit transaction screen
  void _navigateToEditTransaction(
      BuildContext context, TransactionModel transaction) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddTransactionScreen(
          isExpense: transaction.isExpense,
          transactionToEdit: transaction,
        ),
      ),
    );
  }
}
