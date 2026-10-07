import 'package:flutter/material.dart';

import '../../../../core/constants/transaction_categories.dart';
import '../../../../core/services/firebase_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/category_service.dart';

class CategoryManagementPage extends StatefulWidget {
  const CategoryManagementPage({super.key});

  @override
  State<CategoryManagementPage> createState() => _CategoryManagementPageState();
}

class _CategoryManagementPageState extends State<CategoryManagementPage> {
  final _firebase = FirebaseService();
  final _service = CategoryService();
  TransactionCategoryType _type = TransactionCategoryType.expense;
  List<String> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = _firebase.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final categories = await _service.getCategories(user.uid, _type);
      if (mounted) setState(() => _categories = categories);
    } catch (error) {
      _showMessage('No se pudieron cargar las categorías: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addCategory() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nueva categoría'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 32,
          decoration: const InputDecoration(labelText: 'Nombre'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null) return;
    final user = _firebase.currentUser;
    if (user == null) return;
    try {
      final updated = await _service.addCategory(user.uid, _type, name);
      if (mounted) setState(() => _categories = updated);
    } catch (error) {
      _showMessage(
        error is ArgumentError
            ? error.message.toString()
            : 'No se pudo agregar la categoría.',
      );
    }
  }

  Future<void> _removeCategory(String name) async {
    if (_categories.length <= 1) {
      _showMessage('Debe quedar al menos una categoría.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar categoría'),
        content: Text(
          'Se quitará "$name" de las opciones nuevas. Los movimientos anteriores conservarán esta categoría.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final user = _firebase.currentUser;
    if (user == null) return;
    try {
      final updated = await _service.removeCategory(user.uid, _type, name);
      if (mounted) setState(() => _categories = updated);
    } catch (error) {
      _showMessage(
        error is StateError
            ? error.message.toString()
            : 'No se pudo eliminar la categoría.',
      );
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isExpense = _type == TransactionCategoryType.expense;
    return Scaffold(
      appBar: AppBar(title: const Text('Administrar categorías')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCategory,
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SegmentedButton<TransactionCategoryType>(
              segments: const [
                ButtonSegment(
                  value: TransactionCategoryType.expense,
                  label: Text('Gastos'),
                  icon: Icon(Icons.arrow_upward),
                ),
                ButtonSegment(
                  value: TransactionCategoryType.income,
                  label: Text('Ingresos'),
                  icon: Icon(Icons.arrow_downward),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (selection) {
                setState(() => _type = selection.first);
                _load();
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    itemCount: _categories.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final info = isExpense
                          ? TransactionCategories.expenseInfo(category)
                          : TransactionCategories.incomeInfo(category);
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: info.color.withValues(alpha: 0.14),
                            child: Icon(info.icon, color: info.color),
                          ),
                          title: Text(category),
                          trailing: IconButton(
                            tooltip: 'Eliminar $category',
                            onPressed: _categories.length <= 1
                                ? null
                                : () => _removeCategory(category),
                            icon: const Icon(Icons.delete_outline),
                            color: AppTheme.errorColor,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
