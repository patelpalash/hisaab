import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/budget_model.dart';
import '../../models/category_model.dart';
import '../../providers/budget_provider.dart';
import '../../providers/category_provider.dart';

class AddBudgetScreen extends StatefulWidget {
  final String userId;
  final BudgetModel? budgetToEdit;

  const AddBudgetScreen({
    Key? key,
    required this.userId,
    this.budgetToEdit,
  }) : super(key: key);

  @override
  State<AddBudgetScreen> createState() => _AddBudgetScreenState();
}

class _AddBudgetScreenState extends State<AddBudgetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  String? _selectedCategoryId;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  bool _isRecurring = true;
  String _recurrenceType = 'monthly';
  bool _isEditing = false;
  bool _isLoading = false;

  final Color primaryColor = const Color(0xFF6C63FF);

  @override
  void initState() {
    super.initState();

    _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
    _endDate = DateTime(
      _startDate.month == 12 ? _startDate.year + 1 : _startDate.year,
      _startDate.month == 12 ? 1 : _startDate.month + 1,
      0,
    );

    // If editing an existing budget
    if (widget.budgetToEdit != null) {
      _isEditing = true;
      _nameController.text = widget.budgetToEdit!.name;
      _amountController.text = widget.budgetToEdit!.amount.toString();
      _selectedCategoryId = widget.budgetToEdit!.categoryId;
      _startDate = widget.budgetToEdit!.startDate;
      _endDate = widget.budgetToEdit!.endDate;
      _isRecurring = widget.budgetToEdit!.isRecurring;
      _recurrenceType = widget.budgetToEdit!.recurrenceType ?? 'monthly';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 2),
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

    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;

        // Update end date if start date is after end date
        if (_startDate.isAfter(_endDate)) {
          _endDate = _startDate.add(const Duration(days: 30));
        }
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime(_startDate.year + 2),
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

    if (picked != null && picked != _endDate) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<void> _saveBudget() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final budgetProvider =
          Provider.of<BudgetProvider>(context, listen: false);
      final String name = _nameController.text.trim();
      final double amount =
          double.parse(_amountController.text.replaceAll(',', ''));

      bool success;
      if (_isEditing) {
        // Update existing budget
        final updatedBudget = BudgetModel(
          id: widget.budgetToEdit!.id,
          userId: widget.userId,
          name: name,
          amount: amount,
          categoryId: _selectedCategoryId,
          startDate: _startDate,
          endDate: _endDate,
          isRecurring: _isRecurring,
          recurrenceType: _recurrenceType,
          createdAt: widget.budgetToEdit!.createdAt,
          updatedAt: DateTime.now(),
        );

        success = await budgetProvider.updateBudget(updatedBudget);
      } else {
        // Create new budget
        final budget = BudgetModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          userId: widget.userId,
          name: name,
          amount: amount,
          categoryId: _selectedCategoryId,
          startDate: _startDate,
          endDate: _endDate,
          isRecurring: _isRecurring,
          recurrenceType: _recurrenceType,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        success = await budgetProvider.addBudget(budget);
      }

      if (success) {
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to ${_isEditing ? 'update' : 'create'} budget. ${budgetProvider.errorMessage ?? ''}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryProvider = Provider.of<CategoryProvider>(context);

    // Get all expense categories for dropdown
    final expenseCategories = categoryProvider.expenseCategories;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: Text(_isEditing ? 'Edit Budget' : 'Create Budget'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Name field
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Budget Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.label_outline),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a name for this budget';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Amount field
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'Budget Amount',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.currency_rupee),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an amount';
                }
                try {
                  final amount = double.parse(value.replaceAll(',', ''));
                  if (amount <= 0) {
                    return 'Amount must be greater than zero';
                  }
                } catch (e) {
                  return 'Please enter a valid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Category dropdown
            DropdownButtonFormField<String?>(
              value: _selectedCategoryId,
              decoration: InputDecoration(
                labelText: 'Category (Optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.category_outlined),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Overall Budget'),
                ),
                ...expenseCategories.map((category) {
                  return DropdownMenuItem<String?>(
                    value: category.id,
                    child: Row(
                      children: [
                        Icon(
                          category.icon,
                          color: category.color,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(category.name),
                      ],
                    ),
                  );
                }).toList(),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedCategoryId = value;
                });
              },
            ),
            const SizedBox(height: 20),

            // Date range
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectStartDate(context),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Start Date',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.calendar_today),
                      ),
                      child: Text(DateFormat('MMM d, yyyy').format(_startDate)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectEndDate(context),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'End Date',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.calendar_today),
                      ),
                      child: Text(DateFormat('MMM d, yyyy').format(_endDate)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Recurring switch
            SwitchListTile(
              title: const Text('Recurring Budget'),
              subtitle: const Text(
                  'Automatically create a new budget when this one ends'),
              value: _isRecurring,
              activeColor: primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              onChanged: (value) {
                setState(() {
                  _isRecurring = value;
                });
              },
            ),
            const SizedBox(height: 20),

            // Recurrence type
            if (_isRecurring) ...[
              DropdownButtonFormField<String>(
                value: _recurrenceType,
                decoration: InputDecoration(
                  labelText: 'Recurrence Pattern',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.repeat),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'monthly',
                    child: Text('Monthly'),
                  ),
                  DropdownMenuItem(
                    value: 'weekly',
                    child: Text('Weekly'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _recurrenceType = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 20),
            ],

            // Submit button
            SizedBox(
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isLoading ? null : _saveBudget,
                child: _isLoading
                    ? const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      )
                    : Text(_isEditing ? 'Update Budget' : 'Create Budget'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
