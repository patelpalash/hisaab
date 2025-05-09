import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import '../models/transaction_model.dart';
import '../models/category_model.dart';
import '../models/account_model.dart';
import '../providers/auth_provider.dart';
import '../providers/category_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/account_provider.dart';

class AddTransactionScreen extends StatefulWidget {
  static const routeName = '/add-transaction';

  final bool isExpense;
  final TransactionModel? transactionToEdit;

  const AddTransactionScreen({
    Key? key,
    this.isExpense = true,
    this.transactionToEdit,
  }) : super(key: key);

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _amount = '0';
  String _note = '';
  DateTime _selectedDate = DateTime.now();
  String? _selectedCategoryId;
  CategoryModel? _selectedCategory;
  String? _selectedAccountId;
  String? _selectedToAccountId;
  bool _isCalculating = false;
  String _calculationBuffer = '';
  String _operator = '';
  double _previousAmount = 0;
  bool _isEditing = false;
  String? _transactionId;

  // Color variables
  final Color primaryColor = const Color(0xFF6C63FF);
  final Color expenseColor = Colors.red;
  final Color incomeColor = Colors.green;
  final Color transferColor = Colors.blue;

  @override
  void initState() {
    super.initState();

    // Determine if we're editing and set the initial tab
    _isEditing = widget.transactionToEdit != null;
    int initialTab = widget.isExpense ? 0 : 1;

    // If editing, populate values from existing transaction
    if (_isEditing) {
      _transactionId = widget.transactionToEdit!.id;
      _amount = widget.transactionToEdit!.amount.toString();
      _note = widget.transactionToEdit!.notes ?? '';
      _selectedDate = widget.transactionToEdit!.date;
      _selectedCategoryId = widget.transactionToEdit!.categoryId;
      _selectedAccountId = widget.transactionToEdit!.accountId;
      _selectedToAccountId = widget.transactionToEdit!.toAccountId;
      initialTab = widget.transactionToEdit!.isExpense ? 0 : 1;

      // Set the correct tab for transfer
      if (widget.transactionToEdit!.type == TransactionType.transfer) {
        initialTab = 2;
      }
    }

    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: initialTab,
    );

    _tabController.addListener(_handleTabChange);

    // Initialize providers and select the correct category and account
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.isAuthenticated) {
        // Load accounts
        final accountProvider =
            Provider.of<AccountProvider>(context, listen: false);
        if (!_isEditing || _selectedAccountId == null) {
          final accounts = accountProvider.accounts;
          if (accounts.isNotEmpty) {
            setState(() {
              _selectedAccountId = accounts.first.id;
            });
          }
        }

        if (_isEditing) {
          final categoryProvider =
              Provider.of<CategoryProvider>(context, listen: false);
          _selectedCategory =
              categoryProvider.getCategoryById(_selectedCategoryId!);
        } else {
          _updateSelectedCategory();
        }
      }
    });
  }

  void _updateSelectedCategory() {
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);
    final categories = _tabController.index == 0
        ? categoryProvider.expenseCategories
        : _tabController.index == 1
            ? categoryProvider.incomeCategories
            : []; // Transfer doesn't use categories

    if (categories.isNotEmpty && _selectedCategoryId == null) {
      setState(() {
        _selectedCategoryId = categories.first.id;
        _selectedCategory = categories.first;
      });
    }
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        _selectedCategoryId = null;
        _selectedCategory = null;
      });
      _updateSelectedCategory();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Format the amount with commas for thousands
  String _formatAmount() {
    if (_amount == '0') return '0';

    try {
      final value = double.parse(_amount);
      return NumberFormat('#,##0.00').format(value);
    } catch (e) {
      return _amount;
    }
  }

  // Handle number pad button press
  void _handleNumberPress(String value) {
    setState(() {
      if (_isCalculating && _calculationBuffer.isEmpty) {
        _calculationBuffer = value;
      } else if (_isCalculating) {
        _calculationBuffer += value;
      } else if (_amount == '0') {
        _amount = value;
      } else {
        _amount += value;
      }
    });
  }

  // Handle decimal point press
  void _handleDecimalPress() {
    setState(() {
      if (_isCalculating) {
        if (!_calculationBuffer.contains('.')) {
          _calculationBuffer =
              _calculationBuffer.isEmpty ? '0.' : '$_calculationBuffer.';
        }
      } else if (!_amount.contains('.')) {
        _amount = '$_amount.';
      }
    });
  }

  // Handle delete button press
  void _handleDeletePress() {
    setState(() {
      if (_isCalculating && _calculationBuffer.isNotEmpty) {
        _calculationBuffer =
            _calculationBuffer.substring(0, _calculationBuffer.length - 1);
        if (_calculationBuffer.isEmpty) {
          _calculationBuffer = '0';
        }
      } else if (_amount.length > 1) {
        _amount = _amount.substring(0, _amount.length - 1);
      } else {
        _amount = '0';
      }
    });
  }

  // Handle clear button press (long press on delete)
  void _handleClearPress() {
    setState(() {
      if (_isCalculating) {
        _calculationBuffer = '0';
      } else {
        _amount = '0';
      }
    });
  }

  // Handle operator press (+, -, *, /)
  void _handleOperatorPress(String operator) {
    try {
      double currentValue = _isCalculating && _calculationBuffer.isNotEmpty
          ? double.parse(_calculationBuffer)
          : double.parse(_amount);

      setState(() {
        if (_isCalculating && _operator.isNotEmpty) {
          // Perform the previous calculation first
          _calculateResult();
          _operator = operator;
        } else {
          // Start a new calculation
          _previousAmount = currentValue;
          _operator = operator;
          _isCalculating = true;
          _calculationBuffer = '';
        }
      });
    } catch (e) {
      // Handle parsing errors
      print('Error in calculation: $e');
    }
  }

  // Calculate the result and update the amount
  void _calculateResult() {
    try {
      double secondValue =
          _calculationBuffer.isNotEmpty ? double.parse(_calculationBuffer) : 0;

      double result = 0;

      switch (_operator) {
        case '+':
          result = _previousAmount + secondValue;
          break;
        case '-':
          result = _previousAmount - secondValue;
          break;
        case '*':
          result = _previousAmount * secondValue;
          break;
        case '/':
          if (secondValue != 0) {
            result = _previousAmount / secondValue;
          } else {
            // Division by zero
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Cannot divide by zero')),
            );
            return;
          }
          break;
      }

      setState(() {
        _amount = result.toString();
        // Remove trailing zeros after decimal point
        if (_amount.contains('.')) {
          _amount = _amount.replaceAll(RegExp(r'\.0+$'), '');
          _amount = _amount.replaceAll(RegExp(r'(\.\d+?)0+$'), r'$1');
        }

        _isCalculating = false;
        _calculationBuffer = '';
        _operator = '';
      });
    } catch (e) {
      print('Error calculating result: $e');
    }
  }

  // Save the transaction
  Future<void> _saveTransaction() async {
    // Validate inputs
    if (_amount == '0') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an amount')),
      );
      return;
    }

    // Ensure we have a valid category for expense or income
    if ((_tabController.index == 0 || _tabController.index == 1) &&
        _selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    // For transfer, ensure we have both from and to accounts
    if (_tabController.index == 2) {
      if (_selectedAccountId == null || _selectedToAccountId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please select source and destination accounts')),
        );
        return;
      }

      // Ensure from and to accounts are different
      if (_selectedAccountId == _selectedToAccountId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Source and destination accounts must be different')),
        );
        return;
      }
    }

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final transactionProvider =
          Provider.of<TransactionProvider>(context, listen: false);
      final accountProvider =
          Provider.of<AccountProvider>(context, listen: false);

      // Parse amount
      final double amountValue = double.parse(_amount);

      // Determine transaction type
      final bool isExpense = _tabController.index == 0;
      final bool isIncome = _tabController.index == 1;
      final bool isTransfer = _tabController.index == 2;

      if (_isEditing && _transactionId != null) {
        // Update existing transaction
        try {
          final updatedTransaction = TransactionModel(
            id: _transactionId!,
            title: _selectedCategory?.name ??
                (_tabController.index == 2 ? 'Transfer' : 'Transaction'),
            amount: amountValue,
            date: _selectedDate,
            categoryId: _selectedCategoryId ?? '',
            isExpense: isExpense,
            type: isExpense
                ? TransactionType.expense
                : (isIncome
                    ? TransactionType.income
                    : TransactionType.transfer),
            userId: authProvider.user.uid,
            notes: _note.isNotEmpty ? _note : null,
            accountId: _selectedAccountId,
            toAccountId: isTransfer ? _selectedToAccountId : null,
            createdAt: widget.transactionToEdit!
                .createdAt, // Keep the original creation time
            updatedAt: DateTime.now(), // Update the modification time
          );

          // Debug info
          if (kDebugMode) {
            print('Updating transaction:');
            print('ID: ${updatedTransaction.id}');
            print('Title: ${updatedTransaction.title}');
            print('Amount: ${updatedTransaction.amount}');
            print('Date: ${updatedTransaction.date}');
            print('CategoryId: ${updatedTransaction.categoryId}');
            print('IsExpense: ${updatedTransaction.isExpense}');
            print('Type: ${updatedTransaction.type}');
            print('UserId: ${updatedTransaction.userId}');
            print('AccountId: ${updatedTransaction.accountId}');
            print('ToAccountId: ${updatedTransaction.toAccountId}');
            print('Notes: ${updatedTransaction.notes}');
          }

          // For transfers, use the accountProvider to process the transfer
          if (isTransfer) {
            final success = await accountProvider.processTransfer(
              fromAccountId: _selectedAccountId!,
              toAccountId: _selectedToAccountId!,
              amount: amountValue,
              title: _selectedCategory?.name ?? 'Transfer',
              userId: authProvider.user.uid,
              notes: _note.isNotEmpty ? _note : null,
            );

            if (success) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Transfer updated successfully')),
              );
            } else {
              final error = accountProvider.errorMessage;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        'Failed to update transfer${error != null ? ': $error' : ''}')),
              );
            }
          } else {
            // Update the transaction
            final success =
                await transactionProvider.updateTransaction(updatedTransaction);

            if (success) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        '${isExpense ? 'Expense' : 'Income'} updated successfully')),
              );
            } else {
              final error = transactionProvider.errorMessage;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        'Failed to update transaction${error != null ? ': $error' : ''}')),
              );
            }
          }
        } catch (e) {
          print('Error updating transaction: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating transaction: $e')),
          );
        }
      } else {
        // For transfers, use the accountProvider to process the transfer
        if (isTransfer) {
          final success = await accountProvider.processTransfer(
            fromAccountId: _selectedAccountId!,
            toAccountId: _selectedToAccountId!,
            amount: amountValue,
            title: _selectedCategory?.name ?? 'Transfer',
            userId: authProvider.user.uid,
            notes: _note.isNotEmpty ? _note : null,
          );

          if (success) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Transfer completed successfully')),
            );
          } else {
            final error = accountProvider.errorMessage;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      'Failed to create transfer${error != null ? ': $error' : ''}')),
            );
          }
        } else {
          // Create new transaction
          final transaction = TransactionModel.create(
            title: _selectedCategory?.name ?? 'Transaction',
            amount: amountValue,
            date: _selectedDate,
            categoryId: _selectedCategoryId ?? '',
            isExpense: isExpense,
            type: isExpense ? TransactionType.expense : TransactionType.income,
            userId: authProvider.user.uid,
            notes: _note.isNotEmpty ? _note : null,
            accountId:
                _selectedAccountId, // This will be null if no account selected
          );

          // Log transaction details for debugging
          if (kDebugMode) {
            print(
                'Creating transaction: ${transaction.title}, Amount: ${transaction.amount}');
            print('Account ID: ${transaction.accountId}');
            print('Category ID: ${transaction.categoryId}');
          }

          // Save the transaction
          transactionProvider.addTransaction(transaction).then((success) {
            if (success) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        '${isExpense ? 'Expense' : 'Income'} added successfully')),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Failed to add transaction')),
              );
            }
          });
        }
      }
    } catch (e) {
      print('Error saving transaction: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  // Select date
  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(DateTime.now().year - 5),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryProvider = Provider.of<CategoryProvider>(context);
    final accountProvider = Provider.of<AccountProvider>(context);
    final accounts = accountProvider.accounts;

    // Get the appropriate categories based on the selected tab
    final categories = _tabController.index == 0
        ? categoryProvider.expenseCategories
        : _tabController.index == 1
            ? categoryProvider.incomeCategories
            : []; // Transfer doesn't have categories

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: Text(_isEditing ? 'Edit Transaction' : 'Add Transaction'),
        actions: [
          IconButton(
            icon: const Icon(Icons.currency_exchange),
            onPressed: () {
              // TODO: Currency conversion feature for premium users
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: [
            Tab(
              text: 'Expense',
              icon: Icon(Icons.arrow_upward, color: expenseColor),
            ),
            Tab(
              text: 'Income',
              icon: Icon(Icons.arrow_downward, color: incomeColor),
            ),
            Tab(
              text: 'Transfer',
              icon: Icon(Icons.swap_horiz, color: transferColor),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Amount display
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_isCalculating) ...[
                  Text(
                    '$_previousAmount $_operator ${_calculationBuffer.isEmpty ? '' : _calculationBuffer}',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
                Text(
                  '₹${_formatAmount()}',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: _tabController.index == 0
                        ? expenseColor
                        : _tabController.index == 1
                            ? incomeColor
                            : transferColor,
                  ),
                ),
              ],
            ),
          ),

          // Date picker and account in same row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Date button
                OutlinedButton.icon(
                  onPressed: _selectDate,
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    DateFormat('dd MMM').format(_selectedDate),
                    style: TextStyle(fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    minimumSize: Size(0, 36),
                    foregroundColor: primaryColor,
                  ),
                ),

                const SizedBox(width: 8),

                // Note field
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Note',
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                      icon: Icon(Icons.note,
                          color: Colors.grey.shade600, size: 16),
                    ),
                    controller: TextEditingController(text: _note),
                    onChanged: (value) {
                      setState(() {
                        _note = value;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          // Categories
          if (_tabController.index != 2) ...[
            Expanded(
              child: categories.isEmpty
                  ? Center(
                      child: Text(
                        'No ${_tabController.index == 0 ? 'expense' : 'income'} categories available',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.9,
                      ),
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        final isSelected = category.id == _selectedCategoryId;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedCategoryId = category.id;
                              _selectedCategory = category;
                            });
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? category.color
                                      : category.backgroundColor,
                                  shape: BoxShape.circle,
                                  border: isSelected
                                      ? Border.all(
                                          color: category.color,
                                          width: 2,
                                        )
                                      : null,
                                ),
                                child: Icon(
                                  category.icon,
                                  color: isSelected
                                      ? Colors.white
                                      : category.color,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Flexible(
                                child: Text(
                                  category.name,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ] else ...[
            // Transfer UI - simplified
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.swap_vert,
                        size: 64, color: Colors.grey.shade300),
                    SizedBox(height: 16),
                    Text(
                      'Transfer between accounts is disabled',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Number pad
          Container(
            color: Colors.grey.shade100,
            child: Column(
              children: [
                Row(
                  children: [
                    _buildNumberButton('7'),
                    _buildNumberButton('8'),
                    _buildNumberButton('9'),
                    _buildActionButton(
                      'Today',
                      onPressed: () {
                        setState(() {
                          _selectedDate = DateTime.now();
                        });
                      },
                      backgroundColor: primaryColor.withOpacity(0.1),
                      textColor: primaryColor,
                    ),
                  ],
                ),
                Row(
                  children: [
                    _buildNumberButton('4'),
                    _buildNumberButton('5'),
                    _buildNumberButton('6'),
                    _buildActionButton(
                      '+',
                      onPressed: () => _handleOperatorPress('+'),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _buildNumberButton('1'),
                    _buildNumberButton('2'),
                    _buildNumberButton('3'),
                    _buildActionButton(
                      '-',
                      onPressed: () => _handleOperatorPress('-'),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _buildNumberButton('.', onPressed: _handleDecimalPress),
                    _buildNumberButton('0'),
                    _buildActionButton(
                      '⌫',
                      onPressed: _handleDeletePress,
                      onLongPress: _handleClearPress,
                    ),
                    _buildActionButton(
                      '✓',
                      onPressed:
                          _isCalculating ? _calculateResult : _saveTransaction,
                      backgroundColor: primaryColor,
                      textColor: Colors.white,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build number buttons
  Widget _buildNumberButton(String text, {VoidCallback? onPressed}) {
    return Expanded(
      child: Container(
        height: 60,
        margin: const EdgeInsets.all(2),
        child: TextButton(
          onPressed: onPressed ?? () => _handleNumberPress(text),
          style: TextButton.styleFrom(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(0),
            ),
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to build action buttons
  Widget _buildActionButton(
    String text, {
    required VoidCallback onPressed,
    VoidCallback? onLongPress,
    Color backgroundColor = Colors.white,
    Color textColor = Colors.black,
  }) {
    return Expanded(
      child: Container(
        height: 60,
        margin: const EdgeInsets.all(2),
        child: TextButton(
          onPressed: onPressed,
          onLongPress: onLongPress,
          style: TextButton.styleFrom(
            backgroundColor: backgroundColor,
            foregroundColor: textColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(0),
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: text.length > 1 ? 16 : 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
