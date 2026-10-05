import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../../core/theme/app_theme.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayuda'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Icon
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.help_outline,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Center(
                    child: Text(
                      'Cómo usar Chiroless',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Guía rápida para aprovechar al máximo la app',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  _buildSection(
                    context,
                    Icons.attach_money,
                    '1. Registro de Transacciones',
                    'Usa los botones grandes en la pantalla principal para registrar tus "Ingresos" y "Gastos" diarios. Clasifícalos por categoría para un mejor seguimiento.',
                  ),
                  _buildSection(
                    context,
                    Icons.account_balance_wallet,
                    '2. Establece un Presupuesto',
                    'Ve a la sección de Presupuestos para definir límites de gasto mensual por categoría. La app te avisará si te acercas al límite.',
                  ),
                  _buildSection(
                    context,
                    Icons.bar_chart,
                    '3. Visualiza Estadísticas',
                    'En la pestaña de Estadísticas (icono de gráfico) podrás ver gráficos de pastel y barras que muestran dónde se va tu dinero.',
                  ),
                  _buildSection(
                    context,
                    Icons.emoji_events,
                    '4. Cumple Logros',
                    'La sección de Logros te recompensa por buenos hábitos financieros, como ahorrar un porcentaje de tus ingresos o mantenerte bajo presupuesto.',
                  ),
                  _buildSection(
                    context,
                    Icons.auto_awesome,
                    '5. Asistente IA',
                    'Usa el botón flotante (botón mágico) para chatear con el asistente financiero inteligente que te dará consejos personalizados.',
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          // Sección de contacto fuera del scroll
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              border: Border(
                top: BorderSide(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.email_outlined,
                  color: AppTheme.primaryColor,
                  size: 32,
                ),
                const SizedBox(height: 12),
                Text(
                  '¿Necesitas más ayuda?',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Contáctanos en:',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dotenv.env['CONTACT_EMAIL'] ?? 'cargando...',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    IconData icon,
    String title,
    String content,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon and Title outside the card
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Content card
        Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AppTheme.cardGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            content,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.5,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.justify,
          ),
        ),
      ],
    );
  }
}
