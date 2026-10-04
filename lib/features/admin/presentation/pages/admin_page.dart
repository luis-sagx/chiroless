import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../data/admin_service.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final AdminService _adminService = AdminService();
  bool _isLoading = true;
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final stats = await _adminService.getAllUsersStatistics();
      if (mounted) {
        setState(() {
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _exportToCsv() async {
    if (_stats == null || _stats!['rawList'] == null) return;

    try {
      List<Map<String, dynamic>> rawList = _stats!['rawList'];

      List<List<dynamic>> rows = [];
      // Headers
      rows.add([
        "User ID",
        "Email",
        "Group (Period)",
        "Total Income",
        "Total Expense",
        "Balance",
        "Join Date",
      ]);

      // Data
      for (var row in rawList) {
        rows.add([
          row['uid'],
          row['email'],
          row['period'],
          row['income'],
          row['expense'],
          row['balance'],
          row['joinDate'],
        ]);
      }

      String csv = const ListToCsvConverter().convert(rows);

      final directory = await getApplicationDocumentsDirectory();
      final path = "${directory.path}/financial_study_data.csv";
      final File file = File(path);
      await file.writeAsString(csv);

      await Share.shareXFiles([
        XFile(path),
      ], text: 'Financial Control Study Data');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Investigador'), // Research Panel
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadStats),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportToCsv,
            tooltip: 'Exportar CSV',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _stats == null
          ? const Center(child: Text('No hay datos disponibles'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildSummaryCard(),
                  const SizedBox(height: 24),
                  Text(
                    'Comparativa Promedios (Pre vs Post)',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  _buildComparisonChart(),
                  const SizedBox(height: 24),
                  _buildGroupDetailCard(
                    'Grupo PRE',
                    _stats!['preStats'],
                    Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  _buildGroupDetailCard(
                    'Grupo POST',
                    _stats!['postStats'],
                    Colors.green,
                  ),
                  const SizedBox(height: 32),
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'Nota: Para el artículo científico, se recomienda realizar la exportación de datos y analizarlos con herramientas estadísticas externas (SPSS, R, Python).',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'Participantes Totales',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              _stats!['totalUsers'].toString(),
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildMiniStat(
                  'Pre',
                  _stats!['preStats']['count'].toString(),
                  Colors.blue,
                ),
                Container(width: 1, height: 40, color: Colors.grey.shade300),
                _buildMiniStat(
                  'Post',
                  _stats!['postStats']['count'].toString(),
                  Colors.green,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildGroupDetailCard(
    String title,
    Map<String, dynamic> data,
    Color color,
  ) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const Divider(),
            _buildRow(
              'Ingreso Promedio',
              '\$${data['avgIncome'].toStringAsFixed(2)}',
            ),
            _buildRow(
              'Gasto Promedio',
              '\$${data['avgExpense'].toStringAsFixed(2)}',
            ),
            _buildRow('Ratio Ahorro', _calculateSavingsRate(data)),
          ],
        ),
      ),
    );
  }

  String _calculateSavingsRate(Map<String, dynamic> data) {
    double inc = (data['avgIncome'] ?? 0).toDouble();
    double exp = (data['avgExpense'] ?? 0).toDouble();
    if (inc == 0) return '0%';
    double rate = ((inc - exp) / inc) * 100;
    return '${rate.toStringAsFixed(1)}%';
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildComparisonChart() {
    double preAvgExp = (_stats!['preStats']['avgExpense'] as num).toDouble();
    double postAvgExp = (_stats!['postStats']['avgExpense'] as num).toDouble();
    double maxY = (preAvgExp > postAvgExp ? preAvgExp : postAvgExp) * 1.2;
    if (maxY == 0) maxY = 100;

    return SizedBox(
      height: 250,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  switch (value.toInt()) {
                    case 0:
                      return const Text('Promedio Gastos');
                    default:
                      return const Text('');
                  }
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 40),
            ),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          barGroups: [
            BarChartGroupData(
              x: 0,
              barRods: [
                BarChartRodData(toY: preAvgExp, color: Colors.blue, width: 30),
                BarChartRodData(
                  toY: postAvgExp,
                  color: Colors.green,
                  width: 30,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
