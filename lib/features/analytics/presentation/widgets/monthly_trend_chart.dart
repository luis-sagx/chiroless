import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../transactions/data/transaction_service.dart';

/// Barras agrupadas ingresos/gastos de los últimos meses.
class MonthlyTrendChart extends StatelessWidget {
  final List<MonthTotals> data;
  final int months;
  final ValueChanged<int> onMonthsChanged;

  const MonthlyTrendChart({
    super.key,
    required this.data,
    required this.months,
    required this.onMonthsChanged,
  });

  static const List<String> _monthNames = [
    'Ene',
    'Feb',
    'Mar',
    'Abr',
    'May',
    'Jun',
    'Jul',
    'Ago',
    'Sep',
    'Oct',
    'Nov',
    'Dic',
  ];

  String _label(String month) =>
      _monthNames[int.parse(month.substring(5, 7)) - 1];

  static String compact(double v) => v >= 1000
      ? '\$${(v / 1000).toStringAsFixed(1)}k'
      : '\$${v.toStringAsFixed(0)}';

  Widget _legend(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxVal = data.fold<double>(
      0,
      (m, t) => max(m, max(t.income, t.expense)),
    );
    final interval = maxVal > 0 ? maxVal / 4 : 1.0;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Ingresos y gastos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              DropdownButton<int>(
                value: months,
                underline: const SizedBox.shrink(),
                items: const [3, 6, 12]
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text('$value meses'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) onMonthsChanged(value);
                },
              ),
            ],
          ),
          const Text(
            'Incluye el mes actual',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          if (maxVal <= 0) ...[
            const SizedBox(height: 16),
            const Text('Aún no hay movimientos en este periodo'),
          ] else ...[
            const SizedBox(height: 8),
            Row(
              children: [
                _legend(AppTheme.incomeColor, 'Ingresos'),
                const SizedBox(width: 16),
                _legend(AppTheme.expenseColor, 'Gastos'),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: max(constraints.maxWidth, data.length * 44.0 + 44),
                  height: 220,
                  child: BarChart(
                    BarChartData(
                      maxY: maxVal * 1.15,
                      alignment: BarChartAlignment.spaceAround,
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: interval,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: AppTheme.textSecondary.withValues(alpha: 0.12),
                          strokeWidth: 1,
                        ),
                      ),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => AppTheme.primaryColor,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                              BarTooltipItem(
                                '${rodIndex == 0 ? 'Ingresos' : 'Gastos'}\n'
                                '\$${rod.toY.toStringAsFixed(2)}',
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                        ),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 44,
                            interval: interval,
                            getTitlesWidget: (value, meta) => SideTitleWidget(
                              meta: meta,
                              child: Text(
                                compact(value),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            getTitlesWidget: (value, meta) {
                              final i = value.toInt();
                              if (value != i || i < 0 || i >= data.length) {
                                return const SizedBox.shrink();
                              }
                              return SideTitleWidget(
                                meta: meta,
                                child: Text(
                                  _label(data[i].month),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: [
                        for (var i = 0; i < data.length; i++)
                          BarChartGroupData(
                            x: i,
                            barsSpace: 4,
                            barRods: [
                              BarChartRodData(
                                toY: data[i].income,
                                color: AppTheme.incomeColor,
                                width: 10,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                              ),
                              BarChartRodData(
                                toY: data[i].expense,
                                color: AppTheme.expenseColor,
                                width: 10,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
