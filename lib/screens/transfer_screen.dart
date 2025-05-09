import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../models/account_model.dart';
import '../providers/account_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/auth_provider.dart';

class TransferScreen extends StatefulWidget {
  static const routeName = '/transfer';

  const TransferScreen({Key? key}) : super(key: key);

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController(text: 'Transfer');
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedFromAccountId;
  String? _selectedToAccountId;
  DateTime _selectedDate = DateTime.now();

  bool _isLoading = false;
  String? _errorMessage;
  List<AccountModel> _accounts = [];

  @override
  void initState() {
    super.initState();
    // Load accounts after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAccounts();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _loadAccounts() {
    final accountProvider =
        Provider.of<AccountProvider>(context, listen: false);
    setState(() {
      _accounts = accountProvider.accounts;
      // Set default accounts if available
      if (_accounts.length >= 2) {
        _selectedFromAccountId = _accounts[0].id;
        _selectedToAccountId = _accounts[1].id;
      }
    });
  }

  Future<void> _createTransfer() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Additional validation
    if (_selectedFromAccountId == _selectedToAccountId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Source and destination accounts must be different'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final double amount = double.parse(_amountController.text);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final accountProvider =
          Provider.of<AccountProvider>(context, listen: false);

      final success = await accountProvider.processTransfer(
        fromAccountId: _selectedFromAccountId!,
        toAccountId: _selectedToAccountId!,
        amount: amount,
        title: _titleController.text,
        userId: authProvider.user.uid,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      if (success) {
        // Also refresh the transaction list
        final transactionProvider =
            Provider.of<TransactionProvider>(context, listen: false);
        transactionProvider.initTransactions(authProvider.user.uid);

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transfer completed successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to complete transfer. Please try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showDatePicker() {
    showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    ).then((pickedDate) {
      if (pickedDate != null) {
        setState(() {
          _selectedDate = pickedDate;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer Money'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Transfer graphic
                    _buildTransferGraphic(),

                    const SizedBox(height: 24),

                    // From Account
                    _buildAccountDropdown(
                      label: 'From Account',
                      icon: Icons.account_balance_wallet,
                      value: _selectedFromAccountId,
                      excludeId: _selectedToAccountId,
                      onChanged: (newValue) {
                        setState(() {
                          _selectedFromAccountId = newValue;
                        });
                      },
                    ),

                    const SizedBox(height: 16),

                    // To Account
                    _buildAccountDropdown(
                      label: 'To Account',
                      icon: Icons.account_balance,
                      value: _selectedToAccountId,
                      excludeId: _selectedFromAccountId,
                      onChanged: (newValue) {
                        setState(() {
                          _selectedToAccountId = newValue;
                        });
                      },
                    ),

                    const SizedBox(height: 24),

                    // Amount
                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        prefixIcon: Icon(Icons.attach_money),
                        border: OutlineInputBorder(),
                        hintText: '0.00',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an amount';
                        }
                        try {
                          final amount = double.parse(value);
                          if (amount <= 0) {
                            return 'Amount must be greater than zero';
                          }
                          // Check if source account has enough balance
                          if (_selectedFromAccountId != null) {
                            final accountProvider =
                                Provider.of<AccountProvider>(context,
                                    listen: false);
                            final account = accountProvider
                                .getAccountById(_selectedFromAccountId!);
                            if (account != null && amount > account.balance) {
                              return 'Insufficient balance in source account';
                            }
                          }
                        } catch (e) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Date picker
                    InkWell(
                      onTap: _showDatePicker,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date',
                          prefixIcon: Icon(Icons.calendar_today),
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          DateFormat('MMMM dd, yyyy').format(_selectedDate),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Title
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        prefixIcon: Icon(Icons.title),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a title';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Notes
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Notes (Optional)',
                        prefixIcon: Icon(Icons.note),
                        border: OutlineInputBorder(),
                        hintText: 'Add any additional details',
                      ),
                    ),

                    // Error message
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(8),
                        color: Colors.red[100],
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Transfer button
                    ElevatedButton(
                      onPressed: _accounts.length < 2 || _isLoading
                          ? null
                          : _createTransfer,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: theme.primaryColor,
                      ),
                      child: const Text(
                        'TRANSFER MONEY',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),

                    if (_accounts.length < 2) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'You need at least two accounts to make a transfer.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.red,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTransferGraphic() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                const Icon(Icons.account_balance_wallet, size: 40),
                const SizedBox(height: 8),
                Text(
                  _selectedFromAccountId != null
                      ? _accounts
                          .firstWhere((a) => a.id == _selectedFromAccountId)
                          .name
                      : 'From',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Icon(Icons.arrow_forward, size: 32),
            Column(
              children: [
                const Icon(Icons.account_balance, size: 40),
                const SizedBox(height: 8),
                Text(
                  _selectedToAccountId != null
                      ? _accounts
                          .firstWhere((a) => a.id == _selectedToAccountId)
                          .name
                      : 'To',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountDropdown({
    required String label,
    required IconData icon,
    required String? value,
    required ValueChanged<String?> onChanged,
    String? excludeId,
  }) {
    final filteredAccounts =
        _accounts.where((account) => account.id != excludeId).toList();

    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Text('Select $label'),
          onChanged: onChanged,
          items: filteredAccounts.map((account) {
            final displayBalance = NumberFormat.currency(
              symbol: '\$',
              decimalDigits: 2,
            ).format(account.balance);

            return DropdownMenuItem<String>(
              value: account.id,
              child: Row(
                children: [
                  Icon(
                    account.icon,
                    color: account.color,
                  ),
                  const SizedBox(width: 8),
                  Text(account.name),
                  const Spacer(),
                  Text(
                    displayBalance,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
