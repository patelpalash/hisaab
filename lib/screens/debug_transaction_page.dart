import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import '../services/local_database_service.dart';

class DebugTransactionPage extends StatefulWidget {
  final String userId;

  const DebugTransactionPage({Key? key, required this.userId})
      : super(key: key);

  @override
  State<DebugTransactionPage> createState() => _DebugTransactionPageState();
}

class _DebugTransactionPageState extends State<DebugTransactionPage> {
  final LocalDatabaseService _dbService = LocalDatabaseService();
  List<TransactionModel> _transactions = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _successMessage = null;
      });

      final transactions = await _dbService.getTransactions(widget.userId);

      setState(() {
        _transactions = transactions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading transactions: $e';
        _isLoading = false;
      });
      print('Error loading transactions: $e');
    }
  }

  Future<void> _updateTransaction(TransactionModel transaction) async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _successMessage = null;
      });

      // Test updating a transaction directly with the database service
      await _dbService.updateTransaction(transaction);

      setState(() {
        _successMessage = 'Transaction updated successfully!';
        _isLoading = false;
      });

      // Reload transactions
      _loadTransactions();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error updating transaction: $e';
        _isLoading = false;
      });
      print('Error updating transaction: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Transactions'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                if (_successMessage != null)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      _successMessage!,
                      style: const TextStyle(color: Colors.green),
                    ),
                  ),
                Expanded(
                  child: _transactions.isEmpty
                      ? const Center(child: Text('No transactions found'))
                      : ListView.builder(
                          itemCount: _transactions.length,
                          itemBuilder: (context, index) {
                            final transaction = _transactions[index];
                            return ListTile(
                              title: Text(transaction.title),
                              subtitle: Text(
                                  'Amount: ${transaction.amount}, ID: ${transaction.id}'),
                              trailing: ElevatedButton(
                                onPressed: () {
                                  // Create a copy with a modified title for testing
                                  final updatedTransaction = TransactionModel(
                                    id: transaction.id,
                                    title: '${transaction.title} (Updated)',
                                    amount: transaction.amount,
                                    date: transaction.date,
                                    categoryId: transaction.categoryId,
                                    isExpense: transaction.isExpense,
                                    userId: transaction.userId,
                                    notes: transaction.notes,
                                    createdAt: transaction.createdAt,
                                    updatedAt: DateTime.now(),
                                  );
                                  _updateTransaction(updatedTransaction);
                                },
                                child: const Text('Test Update'),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
