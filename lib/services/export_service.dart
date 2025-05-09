import 'dart:io';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:flutter/foundation.dart';
import '../models/transaction_model.dart';
import '../models/budget_model.dart';

class ExportService {
  // Generate and export PDF report
  Future<File> generatePdfReport(List<TransactionModel> transactions,
      String title, DateTime startDate, DateTime endDate) async {
    final pdf = pw.Document();

    // Format dates for display
    final dateFormat = DateFormat('MMM dd, yyyy');
    final formattedStartDate = dateFormat.format(startDate);
    final formattedEndDate = dateFormat.format(endDate);

    // Add content to the PDF
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            _buildReportHeader(title, formattedStartDate, formattedEndDate),
            pw.SizedBox(height: 20),
            _buildTransactionTable(transactions),
            pw.SizedBox(height: 20),
            _buildSummary(transactions),
          ];
        },
      ),
    );

    // Save the PDF to a file
    final output = await getTemporaryDirectory();
    final file = File(
        '${output.path}/hisaab_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());

    return file;
  }

  // Generate and export Excel report
  Future<File> generateExcelReport(List<TransactionModel> transactions,
      String title, DateTime startDate, DateTime endDate) async {
    final excel = Excel.createExcel();
    final sheet = excel['Transactions'];

    // Add header
    final dateFormat = DateFormat('MMM dd, yyyy');
    sheet.appendRow(['Hisaab - $title']);
    sheet.appendRow([
      'Period: ${dateFormat.format(startDate)} to ${dateFormat.format(endDate)}'
    ]);
    sheet.appendRow([]);

    // Add column headers
    sheet.appendRow(['Date', 'Category', 'Description', 'Amount', 'Type']);

    // Add transactions
    for (var transaction in transactions) {
      sheet.appendRow([
        dateFormat.format(transaction.date),
        transaction.categoryId,
        transaction.title,
        transaction.amount.toString(),
        transaction.isExpense ? 'Expense' : 'Income',
      ]);
    }

    // Add summary
    sheet.appendRow([]);
    sheet.appendRow(['Summary']);

    final totalIncome = transactions
        .where((t) => !t.isExpense)
        .fold(0.0, (sum, t) => sum + t.amount);

    final totalExpense = transactions
        .where((t) => t.isExpense)
        .fold(0.0, (sum, t) => sum + t.amount);

    sheet.appendRow(['Total Income:', totalIncome.toString()]);
    sheet.appendRow(['Total Expense:', totalExpense.toString()]);
    sheet.appendRow(['Net Balance:', (totalIncome - totalExpense).toString()]);

    // Save to file
    final output = await getTemporaryDirectory();
    final file = File(
        '${output.path}/hisaab_report_${DateTime.now().millisecondsSinceEpoch}.xlsx');
    await file.writeAsBytes(excel.encode() ?? []);

    return file;
  }

  // Generate and export Budget report (PDF)
  Future<File> generateBudgetReport(
      List<Budget> budgets, String title, DateTime month) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('MMMM yyyy');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            _buildReportHeader(
                'Budget Report - $title', dateFormat.format(month), ''),
            pw.SizedBox(height: 20),
            _buildBudgetTable(budgets),
          ];
        },
      ),
    );

    // Save the PDF to a file
    final output = await getTemporaryDirectory();
    final file = File(
        '${output.path}/hisaab_budget_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());

    return file;
  }

  // Share a file via platform sharing
  Future<void> shareFile(File file, String subject) async {
    try {
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: subject,
        text: 'Exported from Hisaab App',
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error sharing file: $e');
      }
      rethrow;
    }
  }

  // Send email with attachment
  Future<void> sendEmailWithAttachment(
      File file, String subject, String body, List<String> recipients) async {
    final Email email = Email(
      body: body,
      subject: subject,
      recipients: recipients,
      attachmentPaths: [file.path],
      isHTML: false,
    );

    try {
      await FlutterEmailSender.send(email);
    } catch (e) {
      if (kDebugMode) {
        print('Error sending email: $e');
      }
      rethrow;
    }
  }

  // Helper methods for PDF generation
  pw.Widget _buildReportHeader(String title, String startDate, String endDate) {
    String dateRange = endDate.isEmpty ? startDate : '$startDate to $endDate';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Hisaab',
          style: pw.TextStyle(
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Period: $dateRange',
          style: const pw.TextStyle(
            fontSize: 14,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Generated on ${DateFormat('MMM dd, yyyy').format(DateTime.now())}',
          style: const pw.TextStyle(
            fontSize: 12,
            fontStyle: pw.FontStyle.italic,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildTransactionTable(List<TransactionModel> transactions) {
    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: {
        0: const pw.FlexColumnWidth(2), // Date
        1: const pw.FlexColumnWidth(2), // Category
        2: const pw.FlexColumnWidth(3), // Description
        3: const pw.FlexColumnWidth(2), // Amount
        4: const pw.FlexColumnWidth(1), // Type
      },
      children: [
        // Table header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _buildTableCell('Date', isHeader: true),
            _buildTableCell('Category', isHeader: true),
            _buildTableCell('Description', isHeader: true),
            _buildTableCell('Amount', isHeader: true),
            _buildTableCell('Type', isHeader: true),
          ],
        ),
        // Table rows
        ...transactions
            .map(
              (transaction) => pw.TableRow(
                children: [
                  _buildTableCell(
                      DateFormat('MM/dd/yyyy').format(transaction.date)),
                  _buildTableCell(transaction.categoryId),
                  _buildTableCell(transaction.title),
                  _buildTableCell('₹${transaction.amount.toStringAsFixed(2)}'),
                  _buildTableCell(transaction.isExpense ? 'Expense' : 'Income'),
                ],
              ),
            )
            .toList(),
      ],
    );
  }

  pw.Widget _buildBudgetTable(List<Budget> budgets) {
    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: {
        0: const pw.FlexColumnWidth(3), // Category
        1: const pw.FlexColumnWidth(2), // Limit
        2: const pw.FlexColumnWidth(2), // Spent
        3: const pw.FlexColumnWidth(2), // Remaining
      },
      children: [
        // Table header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _buildTableCell('Category', isHeader: true),
            _buildTableCell('Budget Limit', isHeader: true),
            _buildTableCell('Spent', isHeader: true),
            _buildTableCell('Remaining', isHeader: true),
          ],
        ),
        // Table rows
        ...budgets
            .map(
              (budget) => pw.TableRow(
                children: [
                  _buildTableCell(budget.category),
                  _buildTableCell('₹${budget.limit.toStringAsFixed(2)}'),
                  _buildTableCell('₹${budget.spent.toStringAsFixed(2)}'),
                  _buildTableCell(
                      '₹${(budget.limit - budget.spent).toStringAsFixed(2)}'),
                ],
              ),
            )
            .toList(),
      ],
    );
  }

  pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: isHeader ? pw.FontWeight.bold : null,
        ),
      ),
    );
  }

  pw.Widget _buildSummary(List<TransactionModel> transactions) {
    final totalIncome = transactions
        .where((t) => !t.isExpense)
        .fold(0.0, (sum, t) => sum + t.amount);

    final totalExpense = transactions
        .where((t) => t.isExpense)
        .fold(0.0, (sum, t) => sum + t.amount);

    final netBalance = totalIncome - totalExpense;
    final netBalanceColor = netBalance >= 0 ? PdfColors.green : PdfColors.red;

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Summary',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          _buildSummaryRow('Total Income', '₹${totalIncome.toStringAsFixed(2)}',
              PdfColors.green),
          _buildSummaryRow('Total Expense',
              '₹${totalExpense.toStringAsFixed(2)}', PdfColors.red),
          pw.Divider(),
          _buildSummaryRow(
            'Net Balance',
            '₹${netBalance.toStringAsFixed(2)}',
            netBalanceColor,
            isBold: true,
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSummaryRow(String label, String value, PdfColor valueColor,
      {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: isBold ? pw.FontWeight.bold : null,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              color: valueColor,
              fontWeight: isBold ? pw.FontWeight.bold : null,
            ),
          ),
        ],
      ),
    );
  }
}
