import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/services/firebase_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/data/user_service.dart';
import '../../../../models/user_model.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({Key? key}) : super(key: key);

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _nameFormKey = GlobalKey<FormState>();
  final _openingBalanceFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _openingBalanceController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final service = FirebaseService();
  final userService = UserService();
  bool isLoading = true;
  bool isSaving = false;
  AppUser? appUser;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  DateTime _openingBalanceDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _openingBalanceController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final user = service.currentUser;
    if (user != null) {
      final userData = await userService.getUser(user.uid);
      if (mounted) {
        setState(() {
          appUser = userData;
          _nameController.text = userData?.name ?? '';
          _openingBalanceController.text = (userData?.openingBalanceAmount ?? 0)
              .toStringAsFixed(2);
          _openingBalanceDate = userData?.openingBalanceDate ?? DateTime.now();
          isLoading = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_nameFormKey.currentState!.validate()) return;
    await _saveUserData({
      'name': _nameController.text.trim(),
    }, successMessage: 'Nombre actualizado');
  }

  Future<void> _saveOpeningBalance() async {
    if (!_openingBalanceFormKey.currentState!.validate()) return;
    final openingBalance = double.parse(
      _openingBalanceController.text.trim().replaceAll(',', '.'),
    );
    await _saveUserData({
      'openingBalanceAmount': openingBalance,
      'openingBalanceDate': DateTime(
        _openingBalanceDate.year,
        _openingBalanceDate.month,
        _openingBalanceDate.day,
      ),
      'openingBalanceConfigured': true,
    }, successMessage: 'Saldo inicial actualizado');
  }

  Future<void> _saveUserData(
    Map<String, dynamic> data, {
    required String successMessage,
  }) async {
    setState(() => isSaving = true);
    try {
      final user = service.currentUser;
      if (user == null) throw StateError('No hay una sesión activa');
      await userService.updateUser(user.uid, data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> _savePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;
    setState(() => isSaving = true);
    try {
      final user = service.currentUser;
      if (user == null) throw StateError('No hay una sesión activa');
      await user.updatePassword(_passwordController.text);
      _passwordController.clear();
      _confirmPasswordController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contraseña actualizada'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        final message = e.code == 'requires-recent-login'
            ? 'Para cambiar la contraseña, debes iniciar sesión nuevamente'
            : e.code == 'weak-password'
            ? 'La contraseña es muy débil'
            : 'Error al cambiar la contraseña';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cambiar la contraseña: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
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
          'Editar Perfil',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Form(
                    key: _nameFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Datos personales',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Nombre',
                            prefixIcon: const Icon(Icons.person_outline),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'El nombre es requerido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildSaveButton(
                          label: 'Guardar nombre',
                          onPressed: _saveProfile,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 40),
                  Form(
                    key: _openingBalanceFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Saldo inicial',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _openingBalanceController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Dinero disponible',
                            prefixText: '\$ ',
                            prefixIcon: const Icon(
                              Icons.account_balance_wallet,
                            ),
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
                            if (amount == null ||
                                !amount.isFinite ||
                                amount < 0) {
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
                        _buildSaveButton(
                          label: 'Guardar saldo inicial',
                          onPressed: _saveOpeningBalance,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 40),
                  Form(
                    key: _passwordFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Cambiar contraseña',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Nueva contraseña',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Ingresa la nueva contraseña';
                            }
                            if (value.length < 6) {
                              return 'La contraseña debe tener al menos 6 caracteres';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          decoration: InputDecoration(
                            labelText: 'Confirmar nueva contraseña',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () => setState(
                                () => _obscureConfirmPassword =
                                    !_obscureConfirmPassword,
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Confirma tu contraseña';
                            }
                            if (value != _passwordController.text) {
                              return 'Las contraseñas no coinciden';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildSaveButton(
                          label: 'Cambiar contraseña',
                          onPressed: _savePassword,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 56,
                    child: TextButton(
                      onPressed: isSaving ? null : () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSaveButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: isSaving ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: isSaving
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
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
}
