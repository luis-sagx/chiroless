import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_control/shared/widgets/lazy_indexed_stack.dart';

class _TrackedPage extends StatefulWidget {
  const _TrackedPage(this.label, this.onInit);

  final String label;
  final VoidCallback onInit;

  @override
  State<_TrackedPage> createState() => _TrackedPageState();
}

class _TrackedPageState extends State<_TrackedPage> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) => Text(widget.label);
}

void main() {
  testWidgets('mounts secondary pages on first visit and keeps them mounted', (
    tester,
  ) async {
    var statisticsMounts = 0;
    var achievementsMounts = 0;
    Future<void> showTab(int index) => tester.pumpWidget(
      MaterialApp(
        home: LazyIndexedStack(
          index: index,
          builders: [
            (_) => const Text('Inicio'),
            (_) => _TrackedPage('Estadísticas', () => statisticsMounts++),
            (_) => _TrackedPage('Logros', () => achievementsMounts++),
          ],
        ),
      ),
    );

    await showTab(0);
    expect(statisticsMounts, 0);
    expect(achievementsMounts, 0);

    await showTab(1);
    expect(statisticsMounts, 1);
    expect(achievementsMounts, 0);

    await showTab(2);
    expect(statisticsMounts, 1);
    expect(achievementsMounts, 1);

    await showTab(0);
    await showTab(1);
    expect(statisticsMounts, 1);
    expect(achievementsMounts, 1);
  });
}
