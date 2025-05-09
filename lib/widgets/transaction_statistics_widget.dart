import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../models/transaction_model.dart';
import '../providers/category_provider.dart';

class TransactionStatisticsWidget extends StatefulWidget {
  const TransactionStatisticsWidget({Key? key}) : super(key: key);

  @override
  State<TransactionStatisticsWidget> createState() =>
      _TransactionStatisticsWidgetState();
}

class _TransactionStatisticsWidgetState
    extends State<TransactionStatisticsWidget> {
  // Time period selection
  String _selectedPeriod = 'Month';
  final List<String> _periods = ['Week', 'Month', 'Year'];

  // Formatting
  final currencyFormat =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

  // Date calculation
  DateTime get _now => DateTime.now();
  DateTime get _startOfToday => DateTime(_now.year, _now.month, _now.day);

  @override
  Widget build(BuildContext context) {
    final primaryColor = Color(0xFF6C63FF); // App purple theme
    final screenWidth = MediaQuery.of(context).size.width;

    // Prepare transactions data
    final transactionProvider = Provider.of<TransactionProvider>(context);
    final categoryProvider = Provider.of<CategoryProvider>(context);
    final userId = transactionProvider.transactions.isNotEmpty
        ? transactionProvider.transactions.first.userId
        : '';

    final transactions = _getFilteredTransactions(transactionProvider, userId);
    final totalAmount = _calculateTotalAmount(transactions);
    final topSpendingItems =
        _getTopSpendingItems(transactions, categoryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Combined card with total amount and period selector
        Card(
          margin: EdgeInsets.fromLTRB(16, 4, 16, 8),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Total amount row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Balance',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            currencyFormat.format(totalAmount),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      DateFormat('MMMM d, yyyy').format(_now),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 16),

                // Period selector
                Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    children: _periods.map((period) {
                      final isSelected = period == _selectedPeriod;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedPeriod = period;
                            });
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? primaryColor
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(25),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              period,
                              style: TextStyle(
                                color:
                                    isSelected ? Colors.white : Colors.black87,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Chart section
        Card(
          margin: EdgeInsets.fromLTRB(16, 0, 16, 8),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: _buildChartSection(transactions, primaryColor),
        ),

        // Top spending
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            'Top Spending',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),

        // Top spending items
        if (topSpendingItems.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                'No expenses in this period',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            padding: EdgeInsets.only(top: 8, bottom: 16),
            itemCount:
                topSpendingItems.length > 3 ? 3 : topSpendingItems.length,
            itemBuilder: (context, index) {
              final item = topSpendingItems[index];
              return _buildSpendingItem(
                title: item['title'],
                date: item['date'],
                amount: item['amount'],
                icon: item['icon'],
                iconColor: item['iconColor'],
                primaryColor: primaryColor,
              );
            },
          ),
      ],
    );
  }

  Widget _buildChartSection(
      List<TransactionModel> transactions, Color primaryColor) {
    final monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];

    // Get chart data based on selected period
    List<FlSpot> spots = [];
    List<String> labels = [];

    switch (_selectedPeriod) {
      case 'Week':
        // Get last 7 days data
        final today = _startOfToday;

        for (int i = 6; i >= 0; i--) {
          final day = today.subtract(Duration(days: i));
          final dayTotal = _getDayTotal(transactions, day);
          spots.add(FlSpot((6 - i).toDouble(), dayTotal));
          labels.add(DateFormat('E').format(day)); // Mon, Tue, etc.
        }
        break;

      case 'Month':
        // Get data for past 6 months plus current month
        final currentMonth = DateTime(_now.year, _now.month);

        for (int i = 6; i >= 0; i--) {
          final month = DateTime(currentMonth.year, currentMonth.month - i);
          final monthTotal = _getMonthTotal(transactions, month);
          spots.add(FlSpot((6 - i).toDouble(), monthTotal));
          labels.add(monthNames[month.month - 1]);
        }
        break;

      case 'Year':
        // Get yearly data
        final currentYear = DateTime(_now.year);

        for (int i = 4; i >= 0; i--) {
          final year = DateTime(currentYear.year - i);
          final yearTotal = _getYearTotal(transactions, year);
          spots.add(FlSpot((4 - i).toDouble(), yearTotal));
          labels.add(year.year.toString());
        }
        break;
    }

    // Find max value for chart scaling
    double maxY = spots.fold(0, (max, spot) => spot.y > max ? spot.y : max);
    maxY = maxY * 1.2; // Add 20% padding to the top

    // Find current value to display
    double currentValue = spots.isNotEmpty ? spots.last.y : 0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current period value
          if (spots.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  currencyFormat.format(currentValue),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                Text(
                  _selectedPeriod == 'Week'
                      ? 'Last 7 days'
                      : _selectedPeriod == 'Month'
                          ? 'Last 6 months'
                          : 'Last 5 years',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),

          SizedBox(height: 12),

          // Chart
          Container(
            height: 160,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: false,
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: false,
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() < 0 ||
                            value.toInt() >= labels.length) {
                          return const SizedBox();
                        }
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(
                            labels[value.toInt()],
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 11,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: spots.isNotEmpty ? spots.length - 1.0 : 6,
                minY: 0,
                maxY: maxY > 0 ? maxY : 1000,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: primaryColor,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                        radius: 3,
                        color: primaryColor,
                        strokeWidth: 1,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: primaryColor.withOpacity(0.1),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: Colors.blueGrey.shade800,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((LineBarSpot touchedSpot) {
                        return LineTooltipItem(
                          currencyFormat.format(touchedSpot.y),
                          TextStyle(color: Colors.white, fontSize: 12),
                        );
                      }).toList();
                    },
                  ),
                  handleBuiltInTouches: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpendingItem({
    required String title,
    required String date,
    required double amount,
    required IconData icon,
    required Color iconColor,
    required Color primaryColor,
  }) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 18,
              ),
            ),

            SizedBox(width: 12),

            // Transaction details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    date,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // Amount
            Text(
              '-${currencyFormat.format(amount)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods
  List<TransactionModel> _getFilteredTransactions(
      TransactionProvider provider, String userId) {
    final allTransactions =
        provider.transactions.where((t) => t.userId == userId).toList();

    // Filter based on selected period
    final startDate = _getStartDateForPeriod();
    final endDate = _now;

    return allTransactions
        .where((t) =>
            t.date.isAfter(startDate) &&
            t.date.isBefore(endDate.add(Duration(days: 1))))
        .toList();
  }

  DateTime _getStartDateForPeriod() {
    switch (_selectedPeriod) {
      case 'Week':
        return _startOfToday.subtract(Duration(days: 6));
      case 'Month':
        // Last 6 months plus current month
        return DateTime(_now.year, _now.month - 6, 1);
      case 'Year':
        // Last 5 years
        return DateTime(_now.year - 4, 1, 1);
      default:
        return _startOfToday.subtract(Duration(days: 30));
    }
  }

  double _calculateTotalAmount(List<TransactionModel> transactions) {
    double total = 0;

    // For statistics, we might want to include both income and expenses
    // But subtract expenses from income to get net amount
    for (final transaction in transactions) {
      if (transaction.isExpense) {
        total -= transaction.amount;
      } else {
        total += transaction.amount;
      }
    }

    return total;
  }

  List<Map<String, dynamic>> _getTopSpendingItems(
    List<TransactionModel> transactions,
    CategoryProvider categoryProvider,
  ) {
    // Filter expenses only and sort by amount
    final expenses = transactions.where((t) => t.isExpense).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    // Take top 5 expenses
    final topExpenses = expenses.take(5).toList();

    // Format for display
    return topExpenses.map((transaction) {
      // Find category for this transaction
      final category = categoryProvider.getCategoryById(transaction.categoryId);

      // Default icon and color if category not found
      IconData icon = Icons.shopping_cart;
      Color iconColor = Colors.blue;

      if (category != null) {
        icon = category.icon;
        iconColor = category.color;
      }

      return {
        'title': transaction.title,
        'date': DateFormat('d MMM, yyyy').format(transaction.date),
        'amount': transaction.amount,
        'icon': icon,
        'iconColor': iconColor,
      };
    }).toList();
  }

  double _getDayTotal(List<TransactionModel> transactions, DateTime day) {
    final nextDay = day.add(Duration(days: 1));

    final dayTransactions = transactions
        .where((t) =>
            t.date.isAfter(day.subtract(Duration(milliseconds: 1))) &&
            t.date.isBefore(nextDay))
        .toList();

    double total = 0;
    for (final transaction in dayTransactions) {
      if (transaction.isExpense) {
        total -= transaction.amount;
      } else {
        total += transaction.amount;
      }
    }

    return total;
  }

  double _getMonthTotal(List<TransactionModel> transactions, DateTime month) {
    final nextMonth = DateTime(month.year, month.month + 1);

    final monthTransactions = transactions
        .where((t) =>
            t.date.isAfter(month.subtract(Duration(milliseconds: 1))) &&
            t.date.isBefore(nextMonth))
        .toList();

    double total = 0;
    for (final transaction in monthTransactions) {
      if (transaction.isExpense) {
        total -= transaction.amount;
      } else {
        total += transaction.amount;
      }
    }

    return total;
  }

  double _getYearTotal(List<TransactionModel> transactions, DateTime year) {
    final nextYear = DateTime(year.year + 1);

    final yearTransactions = transactions
        .where((t) =>
            t.date.isAfter(year.subtract(Duration(milliseconds: 1))) &&
            t.date.isBefore(nextYear))
        .toList();

    double total = 0;
    for (final transaction in yearTransactions) {
      if (transaction.isExpense) {
        total -= transaction.amount;
      } else {
        total += transaction.amount;
      }
    }

    return total;
  }
}
