import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/transaction_categories.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';

/// Dona de gastos por categoría con el total (o la categoría tocada) al centro.
class CategoryDonutChart extends StatefulWidget {
  final Map<String, double> expensesByCategory;

  const CategoryDonutChart({super.key, required this.expensesByCategory});

  @override
  State<CategoryDonutChart> createState() => _CategoryDonutChartState();
}

class _CategoryDonutChartState extends State<CategoryDonutChart> {
  int? _touchedIndex;

  /// Ordena de mayor a menor y junta en "Otros" lo que pese < 5 % del total.
  List<MapEntry<String, double>> _groupedEntries(double total) {
    final sorted =
        widget.expensesByCategory.entries.where((e) => e.value > 0).toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    final result = <MapEntry<String, double>>[];
    double others = 0;
    for (final entry in sorted) {
      if (entry.key == 'Otros' || entry.value / total < 0.05) {
        others += entry.value;
      } else {
        result.add(entry);
      }
    }
    if (others > 0) result.add(MapEntry('Otros', others));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.expensesByCategory.values.fold<double>(
      0,
      (s, v) => s + v,
    );
    if (total <= 0) return const SizedBox.shrink();

    final entries = _groupedEntries(total);
    final touched = _touchedIndex != null && _touchedIndex! < entries.length
        ? entries[_touchedIndex!]
        : null;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: SizedBox(
        height: 220,
        child: Stack(
          alignment: Alignment.center,
          children: [
            PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 70,
                pieTouchData: PieTouchData(
                  touchCallback: (event, response) {
                    final section = response?.touchedSection;
                    if (!event.isInterestedForInteractions || section == null) {
                      setState(() => _touchedIndex = null);
                      return;
                    }
                    final index = section.touchedSectionIndex;
                    setState(() => _touchedIndex = index < 0 ? null : index);
                  },
                ),
                sections: [
                  for (var i = 0; i < entries.length; i++)
                    PieChartSectionData(
                      color: TransactionCategories.expenseInfo(
                        entries[i].key,
                      ).color,
                      value: entries[i].value,
                      showTitle: false,
                      radius: i == _touchedIndex ? 34 : 28,
                    ),
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  touched?.key ?? 'Total gastado',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${(touched?.value ?? total).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (touched != null)
                  Text(
                    '${(touched.value / total * 100).toStringAsFixed(0)} %',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
