import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../services/export_service.dart';
import '../models/transaction_model.dart';
import '../models/budget_model.dart';

class ExportProvider with ChangeNotifier {
  final ExportService _exportService = ExportService();
  bool _isExporting = false;
  String? _errorMessage;
  File? _lastExportedFile;

  // Getters
  bool get isExporting => _isExporting;
  String? get errorMessage => _errorMessage;
  File? get lastExportedFile => _lastExportedFile;

  // Export transactions as PDF
  Future<File?> exportTransactionsToPdf(List<TransactionModel> transactions,
      String title, DateTime startDate, DateTime endDate) async {
    _setExporting(true);
    _clearError();

    try {
      final file = await _exportService.generatePdfReport(
        transactions,
        title,
        startDate,
        endDate,
      );

      _lastExportedFile = file;
      return file;
    } catch (e) {
      _setError('Failed to generate PDF: ${e.toString()}');
      return null;
    } finally {
      _setExporting(false);
    }
  }

  // Export transactions as Excel
  Future<File?> exportTransactionsToExcel(List<TransactionModel> transactions,
      String title, DateTime startDate, DateTime endDate) async {
    _setExporting(true);
    _clearError();

    try {
      final file = await _exportService.generateExcelReport(
        transactions,
        title,
        startDate,
        endDate,
      );

      _lastExportedFile = file;
      return file;
    } catch (e) {
      _setError('Failed to generate Excel: ${e.toString()}');
      return null;
    } finally {
      _setExporting(false);
    }
  }

  // Export budgets as PDF
  Future<File?> exportBudgetsToPdf(
      List<Budget> budgets, String title, DateTime month) async {
    _setExporting(true);
    _clearError();

    try {
      final file = await _exportService.generateBudgetReport(
        budgets,
        title,
        month,
      );

      _lastExportedFile = file;
      return file;
    } catch (e) {
      _setError('Failed to generate budget report: ${e.toString()}');
      return null;
    } finally {
      _setExporting(false);
    }
  }

  // Share exported file
  Future<bool> shareExportedFile(File file, String subject) async {
    _setExporting(true);
    _clearError();

    try {
      await _exportService.shareFile(file, subject);
      return true;
    } catch (e) {
      _setError('Failed to share file: ${e.toString()}');
      return false;
    } finally {
      _setExporting(false);
    }
  }

  // Email exported file
  Future<bool> emailExportedFile(
      File file, String subject, String body, List<String> recipients) async {
    _setExporting(true);
    _clearError();

    try {
      await _exportService.sendEmailWithAttachment(
        file,
        subject,
        body,
        recipients,
      );
      return true;
    } catch (e) {
      _setError('Failed to email file: ${e.toString()}');
      return false;
    } finally {
      _setExporting(false);
    }
  }

  // Generate monthly summary email
  Future<bool> sendMonthlySummary(List<TransactionModel> transactions,
      List<Budget> budgets, DateTime month, List<String> recipients) async {
    _setExporting(true);
    _clearError();

    try {
      final monthName = DateFormat('MMMM yyyy').format(month);

      // Generate PDF report
      final pdfFile = await _exportService.generatePdfReport(
        transactions,
        'Monthly Summary',
        month,
        DateTime(month.year, month.month + 1, 0), // Last day of month
      );

      // Generate email content
      final totalIncome = transactions
          .where((t) => !t.isExpense)
          .fold(0.0, (sum, t) => sum + t.amount);

      final totalExpense = transactions
          .where((t) => t.isExpense)
          .fold(0.0, (sum, t) => sum + t.amount);

      final netBalance = totalIncome - totalExpense;

      final emailBody = '''
Dear User,

Here is your financial summary for $monthName:

Total Income: ₹${totalIncome.toStringAsFixed(2)}
Total Expenses: ₹${totalExpense.toStringAsFixed(2)}
Net Balance: ₹${netBalance.toStringAsFixed(2)}

Please find the detailed report attached.

Regards,
Hisaab App
''';

      // Send email with attachment
      await _exportService.sendEmailWithAttachment(
        pdfFile,
        'Hisaab - Monthly Summary for $monthName',
        emailBody,
        recipients,
      );

      return true;
    } catch (e) {
      _setError('Failed to send monthly summary: ${e.toString()}');
      return false;
    } finally {
      _setExporting(false);
    }
  }

  // Helper methods
  void _setExporting(bool exporting) {
    _isExporting = exporting;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    if (kDebugMode) {
      print(_errorMessage);
    }
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
