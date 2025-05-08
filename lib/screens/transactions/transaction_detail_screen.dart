import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/transaction_model.dart';
import '../../models/category_model.dart';
import '../../providers/category_provider.dart';
import '../../providers/transaction_provider.dart';

class TransactionDetailScreen extends StatelessWidget {
  final TransactionModel transaction;

  const TransactionDetailScreen({
    Key? key,
    required this.transaction,
  }) : super(key: key);

  // Format currency
  String _formatCurrency(double amount) {
    return '₹${NumberFormat('#,##0.00').format(amount)}';
  }

  @override
  Widget build(BuildContext context) {
    final categoryProvider = Provider.of<CategoryProvider>(context);
    final transactionProvider = Provider.of<TransactionProvider>(context);

    // Get category for this transaction
    final category = categoryProvider.getCategoryById(transaction.categoryId);

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

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF6C63FF),
        title: const Text('Transaction Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              _confirmDelete(context, transactionProvider);
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // TODO: Navigate to edit transaction screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Edit functionality coming soon')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Transaction header card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Category icon
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        color: iconColor,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Transaction title
                    Text(
                      transaction.title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Transaction amount
                    Text(
                      transaction.isExpense
                          ? '- ${_formatCurrency(transaction.amount)}'
                          : '+ ${_formatCurrency(transaction.amount)}',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color:
                            transaction.isExpense ? Colors.red : Colors.green,
                      ),
                    ),

                    // Transaction date with time
                    Text(
                      DateFormat('EEEE, MMMM d, y • h:mm a')
                          .format(transaction.date),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                      ),
                    ),

                    // Transaction type badge
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: transaction.isExpense
                            ? Colors.red.withOpacity(0.1)
                            : Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        transaction.isExpense ? 'Expense' : 'Income',
                        style: TextStyle(
                          color:
                              transaction.isExpense ? Colors.red : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Details section
            Text(
              'Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const Divider(),

            // Category
            _buildDetailRow(
              'Category',
              category?.name ?? 'Uncategorized',
              Icons.category,
            ),

            // Notes (if any)
            if (transaction.notes != null && transaction.notes!.isNotEmpty)
              _buildDetailRow(
                'Notes',
                transaction.notes!,
                Icons.note,
              ),

            // Amount
            _buildDetailRow(
              'Amount',
              _formatCurrency(transaction.amount),
              Icons.attach_money,
            ),

            // Date
            _buildDetailRow(
              'Date',
              DateFormat('MMMM d, y').format(transaction.date),
              Icons.calendar_today,
            ),

            // Time
            _buildDetailRow(
              'Time',
              DateFormat('h:mm a').format(transaction.date),
              Icons.access_time,
            ),

            // Transaction ID
            _buildDetailRow(
              'Transaction ID',
              transaction.id,
              Icons.fingerprint,
            ),

            const SizedBox(height: 32),

            // Current balance information
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: const Color(0xFF6C63FF).withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Transaction Impact',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your balance ${transaction.isExpense ? 'decreased' : 'increased'} by ${_formatCurrency(transaction.amount)} after this transaction.',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to build detail rows
  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.grey.shade600,
            size: 20,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Confirm delete dialog
  void _confirmDelete(BuildContext context, TransactionProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: Text(
          'Are you sure you want to delete this ${transaction.isExpense ? 'expense' : 'income'} of ${_formatCurrency(transaction.amount)}?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog

              // Delete transaction
              final success = await provider.deleteTransaction(transaction.id);

              if (success) {
                Navigator.pop(context); // Go back to list
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Transaction deleted')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to delete transaction')),
                );
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
