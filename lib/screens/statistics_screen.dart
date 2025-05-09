import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import '../providers/transaction_provider.dart';
import '../providers/category_provider.dart';
import '../providers/account_provider.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({Key? key}) : super(key: key);

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen>
    with SingleTickerProviderStateMixin {
  String _timeFrame = 'month'; // Possible values: week, month, year
  final Color primaryColor = const Color(0xFF6C63FF);
  int _selectedTabIndex = 0;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _chartAnimation;

  // For pie chart animation
  int _touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _chartAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Format currency
  String _formatCurrency(double amount) {
    return '₹${NumberFormat('#,##0.00').format(amount)}';
  }

  // Filter transactions based on selected time frame
  List<TransactionModel> _getFilteredTransactions(
      List<TransactionModel> allTransactions) {
    final now = DateTime.now();

    if (_timeFrame == 'week') {
      // Last 7 days
      final weekAgo = now.subtract(Duration(days: 7));
      return allTransactions.where((t) => t.date.isAfter(weekAgo)).toList();
    } else if (_timeFrame == 'month') {
      // Current month
      final startOfMonth = DateTime(now.year, now.month, 1);
      return allTransactions
          .where((t) => t.date.isAfter(startOfMonth))
          .toList();
    } else if (_timeFrame == 'year') {
      // Current year
      final startOfYear = DateTime(now.year, 1, 1);
      return allTransactions.where((t) => t.date.isAfter(startOfYear)).toList();
    }

    // Default to all transactions
    return allTransactions;
  }

  // Get expense data grouped by categories for the pie chart
  List<Map<String, dynamic>> _getCategoryExpenseData(
      List<TransactionModel> transactions, List<CategoryModel> categories) {
    // Map to hold total expenses per category
    final Map<String, double> categoryTotals = {};

    // Calculate totals for each category
    for (var transaction in transactions.where((t) => t.isExpense)) {
      final categoryId = transaction.categoryId;
      if (categoryTotals.containsKey(categoryId)) {
        categoryTotals[categoryId] =
            categoryTotals[categoryId]! + transaction.amount;
      } else {
        categoryTotals[categoryId] = transaction.amount;
      }
    }

    // Convert to list of maps with category info
    final List<Map<String, dynamic>> result = [];
    categoryTotals.forEach((categoryId, total) {
      final category = categories.firstWhere(
        (c) => c.id == categoryId,
        orElse: () => CategoryModel(
          id: 'unknown',
          name: 'Other',
          icon: Icons.circle,
          color: Colors.grey,
          backgroundColor: Colors.grey.shade200,
          isIncome: false,
        ),
      );

      result.add({
        'category': category,
        'amount': total,
      });
    });

    // Sort by amount (descending)
    result.sort((a, b) => b['amount'].compareTo(a['amount']));

    return result;
  }

  // Get daily expense/income data for the line chart
  List<FlSpot> _getDailyData(
      List<TransactionModel> transactions, bool isExpense) {
    // Map to hold daily totals
    final Map<int, double> dailyTotals = {};

    // Determine the number of days to show based on time frame
    int daysToShow =
        _timeFrame == 'week' ? 7 : (_timeFrame == 'month' ? 30 : 365);

    // Calculate start date
    final DateTime endDate = DateTime.now();
    final DateTime startDate = endDate.subtract(Duration(days: daysToShow - 1));

    // Initialize dailyTotals with zeros for all days
    for (int i = 0; i < daysToShow; i++) {
      final dayNumber = i; // Use day index for x-axis
      dailyTotals[dayNumber] = 0.0;
    }

    // Calculate totals for each day
    for (var transaction
        in transactions.where((t) => t.isExpense == isExpense)) {
      if (transaction.date.isBefore(startDate)) continue;
      if (transaction.date.isAfter(endDate)) continue;

      final difference = transaction.date.difference(startDate).inDays;
      if (difference >= 0 && difference < daysToShow) {
        dailyTotals[difference] =
            (dailyTotals[difference] ?? 0.0) + transaction.amount;
      }
    }

    // Convert to FlSpot list for the chart
    final List<FlSpot> spots = [];
    dailyTotals.forEach((day, amount) {
      spots.add(FlSpot(day.toDouble(), amount));
    });

    return spots;
  }

  @override
  Widget build(BuildContext context) {
    final transactionProvider = Provider.of<TransactionProvider>(context);
    final categoryProvider = Provider.of<CategoryProvider>(context);
    final accountProvider = Provider.of<AccountProvider>(context);

    final allTransactions = transactionProvider.transactions;
    final filteredTransactions = _getFilteredTransactions(allTransactions);
    final totalIncome = filteredTransactions
        .where((t) => !t.isExpense)
        .fold(0.0, (sum, t) => sum + t.amount);
    final totalExpenses = filteredTransactions
        .where((t) => t.isExpense)
        .fold(0.0, (sum, t) => sum + t.amount);
    final balance = totalIncome - totalExpenses;

    final expenseCategories = categoryProvider.expenseCategories;
    final categoryExpenseData =
        _getCategoryExpenseData(filteredTransactions, expenseCategories);

    final incomeSpots = _getDailyData(filteredTransactions, false);
    final expenseSpots = _getDailyData(filteredTransactions, true);

    // Determine the maximum value for the line chart y-axis
    final maxY = math.max(
          incomeSpots.isEmpty
              ? 0.0
              : incomeSpots.map((s) => s.y).reduce((a, b) => math.max(a, b)),
          expenseSpots.isEmpty
              ? 0.0
              : expenseSpots.map((s) => s.y).reduce((a, b) => math.max(a, b)),
        ) *
        1.1; // Add 10% padding

    return WillPopScope(
      onWillPop: () async {
        // Navigate back without clearing the stack
        Navigator.of(context).pop();
        return false; // Prevent default back button behavior
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: CustomScrollView(
          slivers: [
            // App Bar
            SliverAppBar(
              expandedHeight: 180.0,
              pinned: true,
              backgroundColor: primaryColor,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  'Financial Insights',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                background: Stack(
                  children: [
                    // Background design with dots pattern
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: primaryColor,
                          // Remove image dependency to avoid errors
                          // image: DecorationImage(
                          //   image: AssetImage('assets/images/dots_pattern.png'),
                          //   fit: BoxFit.cover,
                          //   opacity: 0.1,
                          // ),
                        ),
                      ),
                    ),
                    // Gradient overlay
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              primaryColor.withOpacity(0.8),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Dynamic background decorations
                    ...List.generate(10, (index) {
                      return Positioned(
                        top: math.Random().nextDouble() * 100,
                        left: math.Random().nextDouble() *
                            MediaQuery.of(context).size.width,
                        child: AnimatedBuilder(
                          animation: _animationController,
                          builder: (context, child) {
                            return Opacity(
                              opacity: 0.2 * _fadeAnimation.value,
                              child: Container(
                                width: 20 + (index * 5),
                                height: 20 + (index * 5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  // Navigate back without clearing the stack
                  Navigator.of(context).pop();
                },
              ),
            ),

            // Time period selector
            SliverToBoxAdapter(
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: Transform.translate(
                      offset: Offset(0, _slideAnimation.value),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              _buildTimeFrameButton('Week', 'week'),
                              _buildTimeFrameButton('Month', 'month'),
                              _buildTimeFrameButton('Year', 'year'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Summary Cards
            SliverToBoxAdapter(
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: Transform.translate(
                      offset: Offset(0, _slideAnimation.value),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            _buildSummaryCard(
                              'Balance',
                              _formatCurrency(balance),
                              balance >= 0 ? Colors.indigo : Colors.red,
                              Icons.account_balance_wallet,
                              Colors.indigo.shade50,
                            ),
                            SizedBox(width: 16),
                            _buildSummaryCard(
                              'Income',
                              _formatCurrency(totalIncome),
                              Colors.green,
                              Icons.arrow_downward,
                              Colors.green.shade50,
                            ),
                            SizedBox(width: 16),
                            _buildSummaryCard(
                              'Expense',
                              _formatCurrency(totalExpenses),
                              Colors.red,
                              Icons.arrow_upward,
                              Colors.red.shade50,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Tabs for different charts
            SliverToBoxAdapter(
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Tab selection
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  _buildTabSelector(
                                      'Flow', 0, Icons.show_chart),
                                  SizedBox(width: 16),
                                  _buildTabSelector(
                                      'Categories', 1, Icons.pie_chart),
                                  SizedBox(width: 16),
                                  _buildTabSelector(
                                      'Top Expenses', 2, Icons.list),
                                ],
                              ),
                            ),

                            // Tab content
                            AnimatedBuilder(
                              animation: _chartAnimation,
                              builder: (context, child) {
                                if (_selectedTabIndex == 0) {
                                  // Cash Flow Chart
                                  return Opacity(
                                    opacity: _chartAnimation.value,
                                    child: _buildCashFlowChart(
                                      incomeSpots,
                                      expenseSpots,
                                      maxY,
                                      _chartAnimation.value,
                                    ),
                                  );
                                } else if (_selectedTabIndex == 1) {
                                  // Category Expenses Pie Chart
                                  return Opacity(
                                    opacity: _chartAnimation.value,
                                    child: _buildCategoryPieChart(
                                      categoryExpenseData,
                                      _chartAnimation.value,
                                    ),
                                  );
                                } else {
                                  // Top Expenses List
                                  return Opacity(
                                    opacity: _chartAnimation.value,
                                    child: _buildTopExpensesList(
                                      categoryExpenseData,
                                      totalExpenses,
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Account Summary
            SliverToBoxAdapter(
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: Transform.translate(
                      offset: Offset(0, _slideAnimation.value),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Account Balances',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 16),
                                ...accountProvider.accounts.map((account) {
                                  return _buildAccountItem(account.name,
                                      _formatCurrency(account.balance));
                                }).toList(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Bottom Padding
            SliverToBoxAdapter(
              child: SizedBox(height: 40),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeFrameButton(String label, String value) {
    final isSelected = _timeFrame == value;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _timeFrame = value;
            // Restart animation for charts
            _animationController.reset();
            _animationController.forward();
          });
        },
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey.shade700,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String amount, Color color,
      IconData icon, Color backgroundColor) {
    return Expanded(
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              Spacer(),
              Text(
                amount,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabSelector(String title, int index, IconData icon) {
    final isSelected = _selectedTabIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTabIndex = index;
            // Reset chart animation
            _animationController.reset();
            _animationController.forward();
          });
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color:
                isSelected ? primaryColor.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? primaryColor : Colors.transparent,
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? primaryColor : Colors.grey.shade500,
                size: 20,
              ),
              SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? primaryColor : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCashFlowChart(List<FlSpot> incomeSpots,
      List<FlSpot> expenseSpots, double maxY, double animationValue) {
    // Determine the number of days to show based on time frame
    int daysToShow =
        _timeFrame == 'week' ? 7 : (_timeFrame == 'month' ? 30 : 365);

    // Create x-axis labels based on time frame
    final List<String> bottomTitles = [];
    final DateTime now = DateTime.now();
    final DateTime startDate = now.subtract(Duration(days: daysToShow - 1));

    if (_timeFrame == 'week') {
      for (int i = 0; i < 7; i++) {
        final day = startDate.add(Duration(days: i));
        bottomTitles.add(DateFormat('E').format(day));
      }
    } else if (_timeFrame == 'month') {
      for (int i = 0; i < 30; i += 5) {
        final day = startDate.add(Duration(days: i));
        bottomTitles.add(DateFormat('d').format(day));
      }
    } else {
      // year
      for (int i = 0; i < 12; i++) {
        bottomTitles
            .add(DateFormat('MMM').format(DateTime(now.year, i + 1, 1)));
      }
    }

    return Container(
      height: 300,
      padding: EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 5,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey.shade200,
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const Text('');
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Text(
                      '${NumberFormat.compact().format(value)}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 10,
                      ),
                    ),
                  );
                },
                interval: maxY / 5,
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (_timeFrame == 'week') {
                    int index = value.toInt();
                    if (index >= 0 &&
                        index < bottomTitles.length &&
                        index % 1 == 0) {
                      return Text(
                        bottomTitles[index],
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 10,
                        ),
                      );
                    }
                  } else if (_timeFrame == 'month') {
                    int index = value.toInt();
                    if (index >= 0 && index < 30 && index % 5 == 0) {
                      return Text(
                        DateFormat('d')
                            .format(startDate.add(Duration(days: index))),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 10,
                        ),
                      );
                    }
                  } else {
                    // year
                    int index = value.toInt();
                    if (index >= 0 && index < 365 && index % 30 == 0) {
                      return Text(
                        DateFormat('MMM')
                            .format(startDate.add(Duration(days: index))),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 10,
                        ),
                      );
                    }
                  }
                  return const Text('');
                },
              ),
            ),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: daysToShow.toDouble() - 1,
          minY: 0,
          maxY: maxY,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipBgColor: Colors.black.withOpacity(0.8),
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final isIncome =
                      spot.bar.color == Colors.green.withOpacity(0.5);
                  return LineTooltipItem(
                    '${isIncome ? 'Income' : 'Expense'}: ${_formatCurrency(spot.y)}',
                    TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }).toList();
              },
            ),
          ),
          lineBarsData: [
            // Income line
            LineChartBarData(
              spots: incomeSpots
                  .map((spot) => FlSpot(spot.x, spot.y * animationValue))
                  .toList(),
              isCurved: true,
              color: Colors.green.withOpacity(0.5),
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.green.withOpacity(0.1),
              ),
            ),
            // Expense line
            LineChartBarData(
              spots: expenseSpots
                  .map((spot) => FlSpot(spot.x, spot.y * animationValue))
                  .toList(),
              isCurved: true,
              color: Colors.red.withOpacity(0.5),
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.red.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryPieChart(
      List<Map<String, dynamic>> categoryData, double animationValue) {
    if (categoryData.isEmpty) {
      return Container(
        height: 300,
        child: Center(
          child: Text(
            'No expense data available',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    // Calculate total for percentages
    final total =
        categoryData.fold(0.0, (sum, item) => sum + (item['amount'] as double));

    return Container(
      height: 300,
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Pie chart
          Expanded(
            flex: 4,
            child: Center(
              child: PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            pieTouchResponse == null ||
                            pieTouchResponse.touchedSection == null) {
                          _touchedIndex = -1;
                          return;
                        }
                        _touchedIndex = pieTouchResponse
                            .touchedSection!.touchedSectionIndex;
                      });
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: categoryData.asMap().entries.map((entry) {
                    final index = entry.key;
                    final data = entry.value;
                    final category = data['category'] as CategoryModel;
                    final amount = data['amount'] as double;
                    final percentage = total > 0 ? (amount / total) * 100 : 0;

                    final isTouched = index == _touchedIndex;
                    final double fontSize = isTouched ? 16 : 14;
                    final double radiusMultiplier = isTouched ? 1.1 : 1.0;

                    return PieChartSectionData(
                      color: category.color,
                      value: percentage.toDouble(),
                      title: percentage >= 5
                          ? '${percentage.toStringAsFixed(1)}%'
                          : '',
                      radius: 80 * animationValue * radiusMultiplier,
                      titleStyle: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black26,
                            blurRadius: 2,
                          ),
                        ],
                      ),
                      badgeWidget: _getIcon(category.icon, category.color),
                      badgePositionPercentageOffset: 1.05,
                    );
                  }).toList(),
                ),
              ),
            ),
          ),

          // Category legend
          SizedBox(height: 16),
          Container(
            height: 100,
            child: ListView.builder(
              itemCount:
                  (categoryData.length + 1) ~/ 2, // Ceiling division for pairs
              itemBuilder: (context, rowIndex) {
                return Row(
                  children: [
                    // First item in pair
                    Expanded(
                      child: _buildCategoryLegendItem(
                        categoryData[rowIndex * 2]['category'] as CategoryModel,
                        (categoryData[rowIndex * 2]['amount'] as double),
                        total,
                      ),
                    ),
                    // Second item in pair (if exists)
                    if (rowIndex * 2 + 1 < categoryData.length)
                      Expanded(
                        child: _buildCategoryLegendItem(
                          categoryData[rowIndex * 2 + 1]['category']
                              as CategoryModel,
                          (categoryData[rowIndex * 2 + 1]['amount'] as double),
                          total,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _getIcon(IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Icon(
        icon,
        color: color,
        size: 16,
      ),
    );
  }

  Widget _buildCategoryLegendItem(
      CategoryModel category, double amount, double total) {
    final percentage = total > 0 ? (amount / total) * 100 : 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: category.color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              category.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${percentage.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopExpensesList(
      List<Map<String, dynamic>> categoryData, double totalExpenses) {
    if (categoryData.isEmpty) {
      return Container(
        height: 300,
        child: Center(
          child: Text(
            'No expense data available',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    return Container(
      height: 300,
      padding: EdgeInsets.all(16),
      child: ListView.builder(
        itemCount: categoryData.length,
        itemBuilder: (context, index) {
          final data = categoryData[index];
          final category = data['category'] as CategoryModel;
          final amount = data['amount'] as double;
          final percentage =
              totalExpenses > 0 ? (amount / totalExpenses) * 100 : 0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Row(
              children: [
                // Category icon
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: category.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    category.icon,
                    color: category.color,
                    size: 20,
                  ),
                ),
                SizedBox(width: 16),

                // Category name and percentage
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          // Progress bar
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: percentage / 100,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    category.color),
                                minHeight: 4,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            '${percentage.toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16),

                // Amount
                Text(
                  _formatCurrency(amount),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAccountItem(String accountName, String balance) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.account_balance,
              color: Colors.blueGrey,
              size: 18,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              accountName,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            balance,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
