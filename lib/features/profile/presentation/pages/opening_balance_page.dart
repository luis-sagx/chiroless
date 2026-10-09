import 'package:flutter/material.dart';
import '../../../../core/services/firebase_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/data/user_service.dart';

class OpeningBalancePage extends StatefulWidget {
  const OpeningBalancePage({super.key});

  @override
  State<OpeningBalancePage> createState() => _OpeningBalancePageState();
}

class _OpeningBalancePageState extends State<OpeningBalancePage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _firebaseService = FirebaseService();
  final _userService = UserService();
  DateTime _openingBalanceDate = DateTime.now();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadOpeningBalance();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadOpeningBalance() async {
    final user = _firebaseService.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final userData = await _userService.getUser(user.uid);
    if (!mounted) return;
    setState(() {
      _amountController.text = (userData?.openingBalanceAmount ?? 0)
          .toStringAsFixed(2);
      _openingBalanceDate = userData?.openingBalanceDate ?? DateTime.now();
      _isLoading = false;
    });
  }

  Future<void> _saveOpeningBalance() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final user = _firebaseService.currentUser;
      if (user == null) throw StateError('No hay una sesión activa');
      final amount = double.parse(
        _amountController.text.trim().replaceAll(',', '.'),
      );
      await _userService.updateUser(user.uid, {
        'openingBalanceAmount': amount,
        'openingBalanceDate': DateTime(
          _openingBalanceDate.year,
          _openingBalanceDate.month,
          _openingBalanceDate.day,
        ),
        'openingBalanceConfigured': true,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saldo inicial actualizado'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _selectOpeningBalanceDate() async {
    final today = DateTime.now();
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _openingBalanceDate.isAfter(today)
          ? today
          : _openingBalanceDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(today.year, today.month, today.day),
    );
    if (selectedDate != null && mounted) {
      setState(() {
        _openingBalanceDate = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Saldo inicial',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Dinero disponible',
                        prefixText: '\$ ',
                        prefixIcon: const Icon(Icons.account_balance_wallet),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (value) {
                        final amount = double.tryParse(
                          (value ?? '').trim().replaceAll(',', '.'),
                        );
                        if (amount == null || !amount.isFinite || amount < 0) {
                          return 'Ingresa un monto válido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Saldo disponible al',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _selectOpeningBalanceDate,
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text(
                          '${_openingBalanceDate.day.toString().padLeft(2, '0')}/'
                          '${_openingBalanceDate.month.toString().padLeft(2, '0')}/'
                          '${_openingBalanceDate.year}',
                        ),
                      ),
                    ),
                    const Text(
                      'Los ingresos y gastos registrados desde esta fecha '
                      'se suman al saldo o se restan de él.',
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveOpeningBalance,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Guardar saldo inicial',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
