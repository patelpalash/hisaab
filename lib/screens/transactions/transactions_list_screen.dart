import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../models/transaction_model.dart';
import '../../models/category_model.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/account_provider.dart';
import '../statistics_screen.dart';
import 'transaction_detail_screen.dart';
import '../add_transaction_screen.dart';

class TransactionsListScreen extends StatefulWidget {
  const TransactionsListScreen({Key? key}) : super(key: key);

  @override
  State<TransactionsListScreen> createState() => _TransactionsListScreenState();
}

class _TransactionsListScreenState extends State<TransactionsListScreen>
    with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  bool _showExpenses = true;
  bool _showIncome = true;
  DateTime? _startDate;
  DateTime? _endDate;
  List<String> _selectedCategoryIds = [];
  bool _showSortOptions = false;
  String _sortBy = 'date'; // Options: date, amount, name
  bool _sortAscending = false;

  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;

  final TextEditingController _searchController = TextEditingController();
  final Color primaryColor = const Color(0xFF6C63FF);
  final ScrollController _scrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.125, // 45 degrees
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _searchFocusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Format currency
  String _formatCurrency(double amount) {
    return '₹${NumberFormat('#,##0.00').format(amount)}';
  }

  void _showSortingPopup() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Sort Transactions',
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSortOption(
              title: 'Date',
              icon: Icons.calendar_today,
              sortValue: 'date',
              onTap: () {
                setState(() {
                  if (_sortBy == 'date') {
                    _sortAscending = !_sortAscending;
                  } else {
                    _sortBy = 'date';
                    _sortAscending = false; // Default to newest first
                  }
                });
                Navigator.pop(context);
              },
            ),
            _buildSortOption(
              title: 'Amount',
              icon: Icons.attach_money,
              sortValue: 'amount',
              onTap: () {
                setState(() {
                  if (_sortBy == 'amount') {
                    _sortAscending = !_sortAscending;
                  } else {
                    _sortBy = 'amount';
                    _sortAscending = false; // Default to highest first
                  }
                });
                Navigator.pop(context);
              },
            ),
            _buildSortOption(
              title: 'Name',
              icon: Icons.sort_by_alpha,
              sortValue: 'name',
              onTap: () {
                setState(() {
                  if (_sortBy == 'name') {
                    _sortAscending = !_sortAscending;
                  } else {
                    _sortBy = 'name';
                    _sortAscending = true; // Default to A-Z
                  }
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              _showFilterDialog();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
            ),
            child: Text('More Filters', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildSortOption({
    required String title,
    required IconData icon,
    required String sortValue,
    required VoidCallback onTap,
  }) {
    final bool isSelected = _sortBy == sortValue;

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? primaryColor : Colors.grey.shade600,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? primaryColor : Colors.black87,
        ),
      ),
      trailing: isSelected
          ? Icon(
              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              color: primaryColor,
            )
          : null,
      onTap: onTap,
    );
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

    // Apply sorting
    filteredTransactions.sort((a, b) {
      if (_sortBy == 'date') {
        return _sortAscending
            ? a.date.compareTo(b.date)
            : b.date.compareTo(a.date);
      } else if (_sortBy == 'amount') {
        return _sortAscending
            ? a.amount.compareTo(b.amount)
            : b.amount.compareTo(a.amount);
      } else if (_sortBy == 'name') {
        return _sortAscending
            ? a.title.compareTo(b.title)
            : b.title.compareTo(a.title);
      }
      return b.date.compareTo(a.date); // Default sort by date (newest first)
    });

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              backgroundColor: primaryColor,
              title: const Text('Transactions'),
              pinned: true,
              floating: true,
              leading: IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
              actions: [
                // Sort button
                IconButton(
                  icon: Icon(Icons.sort),
                  onPressed: _showSortingPopup,
                  tooltip: 'Sort Transactions',
                ),
              ],
              bottom: PreferredSize(
                preferredSize: Size.fromHeight(70),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: _buildModernSearchBar(),
                ),
              ),
            ),
          ];
        },
        body: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Current sort order indicator
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Text(
                      'Sorted by:',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                    SizedBox(width: 8),
                    InkWell(
                      onTap: _showSortingPopup,
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _sortBy == 'date'
                                  ? 'Date'
                                  : _sortBy == 'amount'
                                      ? 'Amount'
                                      : 'Name',
                              style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              _sortAscending
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                              size: 14,
                              color: primaryColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Filter chips
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _buildFilterChip(
                      label: 'Expenses',
                      isSelected: _showExpenses,
                      onTap: () {
                        setState(() {
                          _showExpenses = !_showExpenses;
                        });
                      },
                      color: Colors.red,
                    ),
                    const SizedBox(width: 10),
                    _buildFilterChip(
                      label: 'Income',
                      isSelected: _showIncome,
                      onTap: () {
                        setState(() {
                          _showIncome = !_showIncome;
                        });
                      },
                      color: Colors.green,
                    ),
                    const SizedBox(width: 10),
                    if (_startDate != null && _endDate != null)
                      _buildFilterChip(
                        label:
                            '${DateFormat('MMM d').format(_startDate!)} - ${DateFormat('MMM d').format(_endDate!)}',
                        isSelected: true,
                        onTap: () {
                          setState(() {
                            _startDate = null;
                            _endDate = null;
                          });
                        },
                        color: primaryColor,
                        showCloseIcon: true,
                      ),
                    if (_selectedCategoryIds.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: _buildFilterChip(
                          label: '${_selectedCategoryIds.length} categories',
                          isSelected: true,
                          onTap: () {
                            setState(() {
                              _selectedCategoryIds = [];
                            });
                          },
                          color: Colors.amber.shade700,
                          showCloseIcon: true,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Section header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  'All Transactions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Transactions list
            filteredTransactions.isEmpty
                ? SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
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
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
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
                                padding:
                                    const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
                            _buildTransactionItem(
                                context, transaction, category),
                          ],
                        );
                      },
                      childCount: filteredTransactions.length,
                    ),
                  ),

            // Bottom padding
            SliverToBoxAdapter(
              child: SizedBox(height: 80),
            ),
          ],
        ),
      ),
      // Main floating action button for adding transactions
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Stats button
          MouseRegion(
            onEnter: (_) => _animationController.forward(),
            onExit: (_) => _animationController.reverse(),
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: FloatingActionButton.small(
                    heroTag: 'stats-button',
                    onPressed: () {
                      _animationController.reset();
                      // Navigate to statistics screen
                      Navigator.of(context).push(
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  StatisticsScreen(),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                            var tween = Tween(begin: 0.0, end: 1.0)
                                .chain(CurveTween(curve: Curves.easeInOut));
                            var fadeAnimation = animation.drive(tween);
                            return FadeTransition(
                                opacity: fadeAnimation, child: child);
                          },
                        ),
                      );
                    },
                    backgroundColor: Colors.deepPurple.shade300,
                    child: RotationTransition(
                      turns: _rotationAnimation,
                      child: Icon(Icons.insights, color: Colors.white),
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 16),
          // Add transaction button
          FloatingActionButton(
            heroTag: 'add-button',
            onPressed: () {
              // Add new transaction
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => AddTransactionScreen(isExpense: true),
                ),
              );
            },
            backgroundColor: primaryColor,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildModernSearchBar() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Search icon
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Icon(
              Icons.search,
              color: Colors.grey.shade600,
              size: 20,
            ),
          ),

          // TextField
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: 'Search transactions...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
                hintStyle: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 15,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              style: TextStyle(fontSize: 15),
            ),
          ),

          // Clear button (only shown when there's text)
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: Icon(
                Icons.clear,
                color: Colors.grey.shade600,
                size: 20,
              ),
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _searchQuery = '';
                });
              },
              splashRadius: 20,
            ),

          // Divider
          Container(
            height: 24,
            width: 1,
            color: Colors.grey.shade300,
          ),

          // Filter button
          IconButton(
            icon: Icon(
              Icons.filter_list,
              color: Colors.grey.shade700,
              size: 20,
            ),
            onPressed: _showFilterDialog,
            tooltip: 'Filter Transactions',
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

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Color color,
    bool showCloseIcon = false,
  }) {
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: color,
      checkmarkColor: Colors.white,
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}
