import 'package:flutter/material.dart';
import 'dart:math';

class FinancialSummaryChart extends StatefulWidget {
  final double income;
  final double expense;
  final double balance;

  const FinancialSummaryChart({
    Key? key,
    required this.income,
    required this.expense,
    required this.balance,
  }) : super(key: key);

  @override
  State<FinancialSummaryChart> createState() => _FinancialSummaryChartState();
}

class _FinancialSummaryChartState extends State<FinancialSummaryChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();
  }

  @override
  void didUpdateWidget(FinancialSummaryChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Restart animation when data changes
    if (oldWidget.income != widget.income ||
        oldWidget.expense != widget.expense) {
      _animationController.reset();
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calculate total for the pie chart
    final double totalAmount = widget.income + widget.expense;

    // Calculate expense ratio safely
    final double expenseRatio =
        totalAmount > 0 ? widget.expense / totalAmount : 0.0;

    return Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Financial Overview',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(
                Icons.pie_chart,
                color: Theme.of(context).primaryColor,
                size: 24,
              ),
            ],
          ),
          SizedBox(height: 24),
          Center(
            child: SizedBox(
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Pie chart
                  AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      return CustomPaint(
                        size: Size(200, 200),
                        painter: FinancialPieChartPainter(
                          expenseRatio: expenseRatio * _animation.value,
                          incomeColor: Colors.green.shade400,
                          expenseColor: Colors.red.shade400,
                        ),
                      );
                    },
                  ),

                  // Center with balance
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Balance',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '₹${widget.balance.toInt()}',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Legend items
          Padding(
            padding: const EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildLegendItem(
                  'Income',
                  '₹${widget.income.toInt()}',
                  Colors.green.shade400,
                ),
                _buildLegendItem(
                  'Expense',
                  '₹${widget.expense.toInt()}',
                  Colors.red.shade400,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class FinancialPieChartPainter extends CustomPainter {
  final double expenseRatio;
  final Color incomeColor;
  final Color expenseColor;

  FinancialPieChartPainter({
    required this.expenseRatio,
    required this.incomeColor,
    required this.expenseColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;

    final incomeRatio = 1.0 - expenseRatio;

    // Draw income arc (starts at top)
    final incomePaint = Paint()
      ..color = incomeColor
      ..style = PaintingStyle.fill;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2, // Start from top
      2 * pi * incomeRatio, // Draw arc based on income ratio
      true,
      incomePaint,
    );

    // Draw expense arc
    final expensePaint = Paint()
      ..color = expenseColor
      ..style = PaintingStyle.fill;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2 + 2 * pi * incomeRatio, // Start after income arc
      2 * pi * expenseRatio, // Draw arc based on expense ratio
      true,
      expensePaint,
    );

    // Draw center white circle for donut chart
    final centerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius * 0.6, centerPaint);
  }

  @override
  bool shouldRepaint(FinancialPieChartPainter oldDelegate) {
    return oldDelegate.expenseRatio != expenseRatio ||
        oldDelegate.incomeColor != incomeColor ||
        oldDelegate.expenseColor != expenseColor;
  }
}
