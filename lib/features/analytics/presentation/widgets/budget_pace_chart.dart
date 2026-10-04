import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../models/expense_model.dart';
import '../../../../shared/widgets/app_card.dart';
import 'monthly_trend_chart.dart';

/// Gasto acumulado del mes día a día contra la línea ideal del presupuesto.
class BudgetPaceChart extends StatelessWidget {
  final List<Expense> expenses; // gastos del mes actual
  final double budgetLimit;

  const BudgetPaceChart({
    super.key,
    required this.expenses,
    required this.budgetLimit,
  });

  @override
  Widget build(BuildContext context) {
    if (budgetLimit <= 0) return const SizedBox.shrink();

    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daily = List<double>.filled(daysInMonth, 0);
    for (final e in expenses) {
      if (e.date.year == now.year && e.date.month == now.month) {
        daily[e.date.day - 1] += e.amount;
      }
    }

    final spots = <FlSpot>[];
    double accumulated = 0;
    for (var day = 1; day <= now.day; day++) {
      accumulated += daily[day - 1];
      spots.add(FlSpot(day.toDouble(), accumulated));
    }

    final idealToday = budgetLimit / daysInMonth * now.day;
    final isOver = accumulated > idealToday;
    final lineColor = isOver ? AppTheme.expenseColor : AppTheme.incomeColor;
    final maxY = max(budgetLimit, accumulated) * 1.1;

    return AppCard(
      margin: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isOver
                ? 'Vas por encima del ritmo de tu presupuesto'
                : 'Vas dentro del ritmo de tu presupuesto',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: lineColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Gastado: \$${accumulated.toStringAsFixed(2)} · '
            'Ideal a hoy: \$${idealToday.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minX: 1,
                maxX: daysInMonth.toDouble(),
                minY: 0,
                maxY: maxY,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppTheme.textSecondary.withValues(alpha: 0.12),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 5,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) => SideTitleWidget(
                        meta: meta,
                        child: Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      getTitlesWidget: (value, meta) => SideTitleWidget(
                        meta: meta,
                        child: Text(
                          MonthlyTrendChart.compact(value),
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppTheme.primaryColor,
                    getTooltipItems: (touchedSpots) => touchedSpots
                        .map(
                          (s) => LineTooltipItem(
                            s.barIndex == 0
                                ? 'Día ${s.x.toInt()}: \$${s.y.toStringAsFixed(2)}'
                                : 'Ideal: \$${s.y.toStringAsFixed(2)}',
                            const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        )
                        .toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    color: lineColor,
                    barWidth: 3,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: lineColor.withValues(alpha: 0.15),
                    ),
                  ),
                  LineChartBarData(
                    spots: [
                      FlSpot(1, budgetLimit / daysInMonth),
                      FlSpot(daysInMonth.toDouble(), budgetLimit),
                    ],
                    color: AppTheme.textSecondary,
                    barWidth: 1.5,
                    dashArray: [6, 4],
                    dotData: FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
