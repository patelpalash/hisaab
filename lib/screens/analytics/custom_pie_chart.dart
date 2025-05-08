import 'dart:math';
import 'package:flutter/material.dart';

class PieChartSection {
  final String title;
  final double value;
  final Color color;

  PieChartSection({
    required this.title,
    required this.value,
    required this.color,
  });
}

class CustomPieChart extends StatefulWidget {
  final List<PieChartSection> sections;
  final double radius;
  final double centerSpaceRadius;

  const CustomPieChart({
    Key? key,
    required this.sections,
    this.radius = 100.0,
    this.centerSpaceRadius = 40.0,
  }) : super(key: key);

  @override
  State<CustomPieChart> createState() => _CustomPieChartState();
}

class _CustomPieChartState extends State<CustomPieChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalValue =
        widget.sections.fold<double>(0, (sum, section) => sum + section.value);

    // Sort sections by value (larger sections first)
    final sortedSections = List<PieChartSection>.from(widget.sections)
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      height: widget.radius * 2.2, // Add extra space for labels
      width: widget.radius * 2.2,
      child: Stack(
        children: [
          // Center the pie chart
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return CustomPaint(
                  size: Size(widget.radius * 2, widget.radius * 2),
                  painter: PieChartPainter(
                    sections: sortedSections,
                    totalValue: totalValue,
                    centerSpaceRadius: widget.centerSpaceRadius,
                    animationValue: _animation.value,
                  ),
                );
              },
            ),
          ),

          // Center text with count of categories
          if (widget.sections.isNotEmpty)
            Center(
              child: Container(
                width: widget.centerSpaceRadius * 2,
                height: widget.centerSpaceRadius * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 5,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _animation.value,
                      child: child,
                    );
                  },
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${widget.sections.length}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 30,
                            color: Color(0xFF6C63FF),
                          ),
                        ),
                        const Text(
                          'Categories',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Percentage indicators
          ...sortedSections.map((section) {
            final double percentage = totalValue > 0
                ? (section.value / totalValue * 100).toDouble()
                : 0.0;

            // Show small bubble for small percentages
            if (percentage < 10) {
              return _buildSmallPercentageBubble(section, percentage);
            }

            // For large percentages
            return _buildPercentageLabel(
              section: section,
              totalValue: totalValue,
              index: sortedSections.indexOf(section),
              sections: sortedSections,
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildSmallPercentageBubble(PieChartSection section, num percentage) {
    // Calculate the angle for this section on the chart
    double startAngle = -pi / 2; // Start from top

    int index = widget.sections.indexOf(section);
    double totalValue =
        widget.sections.fold<double>(0, (sum, section) => sum + section.value);

    // Calculate the starting angle of this section
    for (int i = 0; i < index; i++) {
      startAngle += 2 * pi * (widget.sections[i].value / totalValue);
    }

    final sweepAngle = 2 * pi * (section.value / totalValue);
    final middleAngle = startAngle + (sweepAngle / 2);

    // Calculate position - place small bubble directly on its segment
    final double x = cos(middleAngle) * (widget.radius * 0.7) + widget.radius;
    final double y = sin(middleAngle) * (widget.radius * 0.7) + widget.radius;

    return Positioned(
      left: (x - 20).toDouble(),
      top: (y - 20).toDouble(),
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Transform.scale(
            scale: _animation.value,
            child: child,
          );
        },
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: section.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: section.color.withOpacity(0.3),
                blurRadius: 5,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Center(
            child: Text(
              '${percentage.round()}%',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPercentageLabel({
    required PieChartSection section,
    required double totalValue,
    required int index,
    required List<PieChartSection> sections,
  }) {
    final percentage =
        totalValue > 0 ? (section.value / totalValue * 100).toDouble() : 0.0;

    // Calculate the angle for this section on the chart
    double startAngle = -pi / 2; // Start from top

    // Calculate the starting angle of this section
    for (int i = 0; i < index; i++) {
      startAngle += 2 * pi * (sections[i].value / totalValue);
    }

    final sweepAngle = 2 * pi * (section.value / totalValue);
    final middleAngle = startAngle + (sweepAngle / 2);

    // Calculate label position
    double labelRadius = widget.radius * 1.1;

    final double x = cos(middleAngle) * labelRadius + widget.radius;
    final double y = sin(middleAngle) * labelRadius + widget.radius;

    return Positioned(
      left: x - 35, // Center the label horizontally
      top: y - 20, // Center the label vertically
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Transform.scale(
            scale: _animation.value,
            child: child,
          );
        },
        child: Container(
          height: 40,
          width: 70,
          decoration: BoxDecoration(
            color: section.color,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: section.color.withOpacity(0.3),
                blurRadius: 5,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Center(
            child: Text(
              '${percentage.round()}%',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PieChartPainter extends CustomPainter {
  final List<PieChartSection> sections;
  final double totalValue;
  final double centerSpaceRadius;
  final double animationValue;

  PieChartPainter({
    required this.sections,
    required this.totalValue,
    required this.centerSpaceRadius,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    if (totalValue <= 0 || sections.isEmpty) {
      final paint = Paint()
        ..color = Colors.grey.shade300
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawCircle(center, radius - 2, paint);
      return;
    }

    double startAngle = -pi / 2; // Start from top

    for (var section in sections) {
      final sweepAngle = 2 * pi * (section.value / totalValue) * animationValue;

      if (sweepAngle > 0.01) {
        // Draw pie slice
        final paint = Paint()
          ..color = section.color
          ..style = PaintingStyle.fill;

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          sweepAngle,
          true,
          paint,
        );

        // Add subtle outline
        final outlinePaint = Paint()
          ..color = Colors.white.withOpacity(0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          sweepAngle,
          true,
          outlinePaint,
        );
      }

      startAngle += sweepAngle;
    }

    // Draw center white circle
    if (centerSpaceRadius > 0) {
      final centerPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;

      canvas.drawCircle(center, centerSpaceRadius, centerPaint);
    }
  }

  @override
  bool shouldRepaint(PieChartPainter oldDelegate) {
    return oldDelegate.sections != sections ||
        oldDelegate.totalValue != totalValue ||
        oldDelegate.centerSpaceRadius != centerSpaceRadius ||
        oldDelegate.animationValue != animationValue;
  }
}
