import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/recurring_transaction_model.dart';
import '../models/category_model.dart';
import '../services/database_service.dart';
import '../services/local_database_service.dart';
import '../providers/auth_provider.dart';
import '../widgets/empty_state.dart';
import '../providers/transaction_provider.dart';
import '../providers/category_provider.dart';

class RecurringTransactionsScreen extends StatefulWidget {
  static const routeName = '/recurring-transactions';

  const RecurringTransactionsScreen({Key? key}) : super(key: key);

  @override
  State<RecurringTransactionsScreen> createState() =>
      _RecurringTransactionsScreenState();
}

class _RecurringTransactionsScreenState
    extends State<RecurringTransactionsScreen> {
  final DatabaseService _dbService = DatabaseService();
  late final AuthProvider _authProvider;
  late final String _userId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _authProvider = Provider.of<AuthProvider>(context, listen: false);
    _userId = _authProvider.user.uid;

    // Use Future.microtask to avoid setState during build
    Future.microtask(() {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get categories and reset loading state - transactions are managed by provider
      final categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);

      // Initialize categories using Future
      await Future(() => categoryProvider.initCategories(_userId));

      // Force the provider to properly initialize (will be handled in initState)
      final transactionProvider =
          Provider.of<TransactionProvider>(context, listen: false);
      if (transactionProvider.transactions.isEmpty) {
        transactionProvider.initTransactions(_userId);
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: ${e.toString()}')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getCategoryName(String categoryId) {
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);
    final categories = categoryProvider.categories;
    final category = categories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => CategoryModel.defaultExpenseCategories().first,
    );
    return category.name;
  }

  String _getFrequencyText(RecurrenceFrequency frequency) {
    switch (frequency) {
      case RecurrenceFrequency.daily:
        return 'Daily';
      case RecurrenceFrequency.weekly:
        return 'Weekly';
      case RecurrenceFrequency.biweekly:
        return 'Bi-weekly';
      case RecurrenceFrequency.monthly:
        return 'Monthly';
      case RecurrenceFrequency.quarterly:
        return 'Quarterly';
      case RecurrenceFrequency.yearly:
        return 'Yearly';
    }
  }

  String _getRecurringDetails(RecurringTransactionModel transaction) {
    String text = _getFrequencyText(transaction.frequency);

    if (transaction.frequency == RecurrenceFrequency.weekly &&
        transaction.dayOfWeek != null) {
      final days = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday'
      ];
      text += ' on ${days[transaction.dayOfWeek! - 1]}';
    } else if (transaction.frequency == RecurrenceFrequency.monthly &&
        transaction.dayOfMonth != null) {
      text += ' on day ${transaction.dayOfMonth}';
    }

    text += ' starting ${DateFormat('MMM d, y').format(transaction.startDate)}';

    if (transaction.endDate != null) {
      text += ' until ${DateFormat('MMM d, y').format(transaction.endDate!)}';
    }

    return text;
  }

  Future<void> _deleteRecurringTransaction(
      RecurringTransactionModel transaction) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Recurring Transaction'),
        content: Text(
            'Are you sure you want to delete "${transaction.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final provider = Provider.of<TransactionProvider>(context, listen: false);
      final success = await provider.deleteRecurringTransaction(transaction.id);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recurring transaction deleted')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${provider.errorMessage}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Error deleting recurring transaction: ${e.toString()}')),
      );
    }
  }

  Future<void> _toggleActive(RecurringTransactionModel transaction) async {
    try {
      final updatedTransaction = transaction.copyWith(
        isActive: !transaction.isActive,
        updatedAt: DateTime.now(),
      );

      final provider = Provider.of<TransactionProvider>(context, listen: false);
      final success =
          await provider.updateRecurringTransaction(updatedTransaction);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(transaction.isActive
                ? 'Recurring transaction paused'
                : 'Recurring transaction activated'),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${provider.errorMessage}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Error updating recurring transaction: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring Transactions'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Consumer<TransactionProvider>(
              builder: (context, transactionProvider, child) {
              final recurringTransactions =
                  transactionProvider.recurringTransactions;

              if (recurringTransactions.isEmpty) {
                return EmptyState(
                  icon: Icons.replay_circle_filled,
                  title: 'No Recurring Transactions',
                  description:
                      'You haven\'t set up any recurring transactions yet.',
                  buttonText: 'Add Your First',
                  onPressed: () {
                    // Navigate to add recurring transaction form
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RecurringTransactionForm(
                          onSave: (newTransaction) {
                            // Will be handled by provider
                          },
                        ),
                      ),
                    );
                  },
                );
              }

              return ListView.builder(
                itemCount: recurringTransactions.length,
                itemBuilder: (ctx, index) {
                  final transaction = recurringTransactions[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(
                                      transaction.isExpense
                                          ? Icons.arrow_upward
                                          : Icons.arrow_downward,
                                      color: transaction.isExpense
                                          ? Colors.red
                                          : Colors.green,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        transaction.title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${transaction.isExpense ? '-' : '+'}\$${transaction.amount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: transaction.isExpense
                                      ? Colors.red
                                      : Colors.green,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _getCategoryName(transaction.categoryId),
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _getRecurringDetails(transaction),
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                    if (transaction.notes != null &&
                                        transaction.notes!.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        transaction.notes!,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // Status chip
                              Chip(
                                label: Text(
                                  transaction.isActive ? 'Active' : 'Paused',
                                  style: TextStyle(
                                    color: transaction.isActive
                                        ? Colors.green.shade800
                                        : Colors.grey.shade700,
                                  ),
                                ),
                                backgroundColor: transaction.isActive
                                    ? Colors.green.shade50
                                    : Colors.grey.shade200,
                              ),
                              const Spacer(),
                              // Toggle active state
                              IconButton(
                                icon: Icon(
                                  transaction.isActive
                                      ? Icons.pause_circle_outline
                                      : Icons.play_circle_outline,
                                ),
                                onPressed: () => _toggleActive(transaction),
                                tooltip: transaction.isActive
                                    ? 'Pause recurring transaction'
                                    : 'Activate recurring transaction',
                              ),
                              // Edit button
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          RecurringTransactionForm(
                                        existingTransaction: transaction,
                                        onSave: (updatedTransaction) {
                                          // Will be handled by provider
                                        },
                                      ),
                                    ),
                                  );
                                },
                                tooltip: 'Edit',
                              ),
                              // Delete button
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () =>
                                    _deleteRecurringTransaction(transaction),
                                tooltip: 'Delete',
                                color: Colors.red,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }),
      floatingActionButton:
          Consumer<TransactionProvider>(builder: (context, provider, child) {
        return provider.recurringTransactions.isEmpty
            ? Container()
            : FloatingActionButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RecurringTransactionForm(
                        onSave: (newTransaction) {
                          // Will be handled by provider
                        },
                      ),
                    ),
                  );
                },
                child: const Icon(Icons.add),
              );
      }),
    );
  }
}

class RecurringTransactionForm extends StatefulWidget {
  final RecurringTransactionModel? existingTransaction;
  final Function(RecurringTransactionModel) onSave;

  const RecurringTransactionForm({
    Key? key,
    this.existingTransaction,
    required this.onSave,
  }) : super(key: key);

  @override
  State<RecurringTransactionForm> createState() =>
      _RecurringTransactionFormState();
}

class _RecurringTransactionFormState extends State<RecurringTransactionForm> {
  late final AuthProvider _authProvider;
  late final String _userId;

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isExpense = true;
  String? _selectedCategoryId;
  RecurrenceFrequency _frequency = RecurrenceFrequency.monthly;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  int? _dayOfMonth;
  int? _dayOfWeek;
  bool _isActive = true;
  bool _isLoading = true;

  List<CategoryModel> _expenseCategories = [];
  List<CategoryModel> _incomeCategories = [];

  @override
  void initState() {
    super.initState();
    _authProvider = Provider.of<AuthProvider>(context, listen: false);
    _userId = _authProvider.user.uid;

    // Use Future.microtask to avoid setState during build
    Future.microtask(() {
      _loadCategories().then((_) {
        if (widget.existingTransaction != null) {
          _populateFormWithExistingData();
        }
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      });
    });
  }

  Future<void> _loadCategories() async {
    try {
      final categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);
      final categories = categoryProvider.categories;

      if (categories.isEmpty) {
        // Use Future to avoid setState during build
        await Future(() => categoryProvider.initCategories(_userId));
      }

      _expenseCategories = categoryProvider.expenseCategories;
      _incomeCategories = categoryProvider.incomeCategories;

      if (mounted) {
        setState(() {
          // Set default category
          if (_selectedCategoryId == null) {
            if (_isExpense && _expenseCategories.isNotEmpty) {
              _selectedCategoryId = _expenseCategories.first.id;
            } else if (!_isExpense && _incomeCategories.isNotEmpty) {
              _selectedCategoryId = _incomeCategories.first.id;
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading categories: ${e.toString()}')),
        );
      }
    }
  }

  void _populateFormWithExistingData() {
    final transaction = widget.existingTransaction!;
    _titleController.text = transaction.title;
    _amountController.text = transaction.amount.toString();
    _notesController.text = transaction.notes ?? '';
    _isExpense = transaction.isExpense;
    _selectedCategoryId = transaction.categoryId;
    _frequency = transaction.frequency;
    _startDate = transaction.startDate;
    _endDate = transaction.endDate;
    _dayOfMonth = transaction.dayOfMonth;
    _dayOfWeek = transaction.dayOfWeek;
    _isActive = transaction.isActive;
  }

  Future<void> _saveRecurringTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final double amount = double.parse(_amountController.text);

      final RecurringTransactionModel recurringTransaction =
          widget.existingTransaction != null
              ? widget.existingTransaction!.copyWith(
                  title: _titleController.text.trim(),
                  amount: amount,
                  categoryId: _selectedCategoryId!,
                  isExpense: _isExpense,
                  notes: _notesController.text.trim().isEmpty
                      ? null
                      : _notesController.text.trim(),
                  frequency: _frequency,
                  startDate: _startDate,
                  endDate: _endDate,
                  dayOfMonth: _dayOfMonth,
                  dayOfWeek: _dayOfWeek,
                  isActive: _isActive,
                  updatedAt: DateTime.now(),
                )
              : RecurringTransactionModel.create(
                  title: _titleController.text.trim(),
                  amount: amount,
                  categoryId: _selectedCategoryId!,
                  isExpense: _isExpense,
                  userId: _userId,
                  notes: _notesController.text.trim().isEmpty
                      ? null
                      : _notesController.text.trim(),
                  frequency: _frequency,
                  startDate: _startDate,
                  endDate: _endDate,
                  isActive: _isActive,
                  dayOfMonth: _dayOfMonth,
                  dayOfWeek: _dayOfWeek,
                );

      final provider = Provider.of<TransactionProvider>(context, listen: false);
      bool success;

      if (widget.existingTransaction != null) {
        // Update existing transaction
        success =
            await provider.updateRecurringTransaction(recurringTransaction);
      } else {
        // Create new transaction
        success = await provider.addRecurringTransaction(recurringTransaction);
      }

      if (success) {
        widget.onSave(recurringTransaction);

        // Close form
        Navigator.pop(context);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existingTransaction != null
                ? 'Recurring transaction updated'
                : 'Recurring transaction created'),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${provider.errorMessage}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Error saving recurring transaction: ${e.toString()}')),
      );
    }
  }

  String _getFrequencyLabel(RecurrenceFrequency frequency) {
    switch (frequency) {
      case RecurrenceFrequency.daily:
        return 'Daily';
      case RecurrenceFrequency.weekly:
        return 'Weekly';
      case RecurrenceFrequency.biweekly:
        return 'Bi-weekly';
      case RecurrenceFrequency.monthly:
        return 'Monthly';
      case RecurrenceFrequency.quarterly:
        return 'Quarterly';
      case RecurrenceFrequency.yearly:
        return 'Yearly';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingTransaction != null
            ? 'Edit Recurring Transaction'
            : 'Add Recurring Transaction'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Transaction type toggle
                    Row(
                      children: [
                        const Text('Transaction Type:'),
                        const SizedBox(width: 16),
                        ChoiceChip(
                          label: const Text('Expense'),
                          selected: _isExpense,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _isExpense = true;
                                // Reset category selection
                                _selectedCategoryId =
                                    _expenseCategories.isNotEmpty
                                        ? _expenseCategories.first.id
                                        : null;
                              });
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Income'),
                          selected: !_isExpense,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _isExpense = false;
                                // Reset category selection
                                _selectedCategoryId =
                                    _incomeCategories.isNotEmpty
                                        ? _incomeCategories.first.id
                                        : null;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Title
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a title';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Amount
                    TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        border: OutlineInputBorder(),
                        prefixText: '\$',
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter an amount';
                        }
                        try {
                          final amount = double.parse(value);
                          if (amount <= 0) {
                            return 'Amount must be greater than zero';
                          }
                        } catch (e) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Category dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedCategoryId,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items:
                          (_isExpense ? _expenseCategories : _incomeCategories)
                              .map((category) {
                        return DropdownMenuItem<String>(
                          value: category.id,
                          child: Row(
                            children: [
                              Icon(category.icon, color: category.color),
                              const SizedBox(width: 8),
                              Text(category.name),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCategoryId = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a category';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Frequency dropdown
                    DropdownButtonFormField<RecurrenceFrequency>(
                      value: _frequency,
                      decoration: const InputDecoration(
                        labelText: 'Frequency',
                        border: OutlineInputBorder(),
                      ),
                      items: RecurrenceFrequency.values.map((frequency) {
                        return DropdownMenuItem<RecurrenceFrequency>(
                          value: frequency,
                          child: Text(_getFrequencyLabel(frequency)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _frequency = value!;
                          // Reset day fields when frequency changes
                          if (value != RecurrenceFrequency.monthly) {
                            _dayOfMonth = null;
                          }
                          if (value != RecurrenceFrequency.weekly) {
                            _dayOfWeek = null;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Additional options based on frequency
                    if (_frequency == RecurrenceFrequency.weekly) ...[
                      const Text('Repeat on day:'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8.0,
                        children: [
                          for (int i = 1; i <= 7; i++)
                            ChoiceChip(
                              label: Text([
                                'Mon',
                                'Tue',
                                'Wed',
                                'Thu',
                                'Fri',
                                'Sat',
                                'Sun'
                              ][i - 1]),
                              selected: _dayOfWeek == i,
                              onSelected: (selected) {
                                setState(() {
                                  _dayOfWeek = selected ? i : null;
                                });
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (_frequency == RecurrenceFrequency.monthly) ...[
                      const Text('Repeat on day of month:'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8.0,
                        children: [
                          for (int i = 1; i <= 31; i += 5)
                            Wrap(
                              spacing: 8.0,
                              children: [
                                for (int j = i; j < i + 5 && j <= 31; j++)
                                  ChoiceChip(
                                    label: Text(j.toString()),
                                    selected: _dayOfMonth == j,
                                    onSelected: (selected) {
                                      setState(() {
                                        _dayOfMonth = selected ? j : null;
                                      });
                                    },
                                  ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Start date picker
                    ListTile(
                      title: const Text('Start Date'),
                      subtitle: Text(DateFormat('MMM d, y').format(_startDate)),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _startDate,
                          firstDate:
                              DateTime.now().subtract(const Duration(days: 30)),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365 * 2)),
                        );
                        if (picked != null) {
                          setState(() {
                            _startDate = picked;
                            // Ensure end date is not before start date
                            if (_endDate != null &&
                                _endDate!.isBefore(_startDate)) {
                              _endDate = null;
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 8),

                    // End date picker (optional)
                    ListTile(
                      title: const Text('End Date (Optional)'),
                      subtitle: _endDate != null
                          ? Text(DateFormat('MMM d, y').format(_endDate!))
                          : const Text('No End Date'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_endDate != null)
                            IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _endDate = null;
                                });
                              },
                            ),
                          const Icon(Icons.calendar_today),
                        ],
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _endDate ??
                              _startDate.add(const Duration(days: 30)),
                          firstDate: _startDate,
                          lastDate: DateTime.now()
                              .add(const Duration(days: 365 * 10)),
                        );
                        if (picked != null) {
                          setState(() {
                            _endDate = picked;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Notes
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes (Optional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),

                    // Active status
                    SwitchListTile(
                      title: const Text('Status'),
                      subtitle: Text(_isActive ? 'Active' : 'Paused'),
                      value: _isActive,
                      onChanged: (value) {
                        setState(() {
                          _isActive = value;
                        });
                      },
                    ),
                    const SizedBox(height: 24),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _saveRecurringTransaction,
                        child: Text(
                          widget.existingTransaction != null
                              ? 'Update'
                              : 'Save',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
