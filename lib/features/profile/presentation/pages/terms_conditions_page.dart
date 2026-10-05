import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class TermsConditionsPage extends StatelessWidget {
  const TermsConditionsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Términos y Condiciones'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
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
                  Icons.description_outlined,
                  size: 48,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 24),

            Center(
              child: Text(
                'Términos y Condiciones de Uso',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Por favor, lee estos términos cuidadosamente',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
              ),
            ),
            const SizedBox(height: 32),

            _buildSection(
              context,
              '1. Aceptación de los Términos',
              'Al acceder y utilizar Chiroless, aceptas estar sujeto a estos términos y condiciones. Si no estás de acuerdo con alguna parte de estos términos, no debes utilizar nuestra aplicación.',
            ),
            const SizedBox(height: 20),
            _buildSection(
              context,
              '2. Uso de la Aplicación',
              'Chiroless es una herramienta de gestión financiera personal. Te comprometes a utilizar la aplicación solo para fines legales y de acuerdo con estos términos. No debes usar la aplicación de ninguna manera que pueda dañar, deshabilitar o perjudicar la aplicación o interferir con el uso de otros usuarios.',
            ),
            const SizedBox(height: 20),
            _buildSection(
              context,
              '3. Privacidad y Protección de Datos',
              'Tu privacidad es importante para nosotros. Toda la información financiera que ingreses en Chiroless es almacenada de forma segura en Firebase. No compartimos tus datos personales con terceros sin tu consentimiento explícito.',
            ),
            const SizedBox(height: 20),
            _buildSection(
              context,
              '4. Uso de Datos para Investigación Académica',
              'Esta aplicación forma parte de un proyecto de investigación académica. Los datos agregados y anonimizados de uso de la aplicación podrán ser utilizados para análisis estadísticos con fines académicos y de investigación sobre hábitos financieros de estudiantes universitarios. Tu información personal identificable nunca será compartida y se mantendrá la confidencialidad en todo momento. El análisis se realizará exclusivamente con propósitos educativos y de investigación científica.',
            ),
            const SizedBox(height: 20),
            _buildSection(
              context,
              '5. Cuenta de Usuario',
              'Eres responsable de mantener la confidencialidad de tu cuenta y contraseña. Aceptas notificarnos inmediatamente sobre cualquier uso no autorizado de tu cuenta. No nos hacemos responsables de ninguna pérdida o daño que resulte del incumplimiento de esta obligación.',
            ),
            const SizedBox(height: 20),
            _buildSection(
              context,
              '6. Información Financiera',
              'Chiroless proporciona herramientas para el seguimiento y análisis de tus finanzas personales. La información y recomendaciones proporcionadas por la aplicación son solo para fines informativos y educativos. No constituyen asesoramiento financiero profesional.',
            ),
            const SizedBox(height: 20),
            _buildSection(
              context,
              '7. Propiedad Intelectual',
              'Todo el contenido, diseño, gráficos, interfaces y código de Chiroless son propiedad exclusiva de sus desarrolladores y están protegidos por las leyes de derechos de autor. No puedes copiar, modificar, distribuir o reproducir ningún contenido sin autorización previa por escrito.',
            ),
            const SizedBox(height: 20),
            _buildSection(
              context,
              '8. Limitación de Responsabilidad',
              'Chiroless se proporciona "tal cual" sin garantías de ningún tipo. No garantizamos que la aplicación será ininterrumpida o libre de errores. No seremos responsables de ningún daño directo, indirecto, incidental o consecuente que resulte del uso o la incapacidad de usar la aplicación.',
            ),
            const SizedBox(height: 20),
            _buildSection(
              context,
              '9. Modificaciones',
              'Nos reservamos el derecho de modificar estos términos en cualquier momento. Te notificaremos sobre cambios significativos. El uso continuado de la aplicación después de dichos cambios constituirá tu aceptación de los nuevos términos.',
            ),
            const SizedBox(height: 20),
            _buildSection(
              context,
              '10. Contacto',
              'Si tienes preguntas sobre estos términos y condiciones, puedes contactarnos a través de la sección de ayuda en la aplicación.',
            ),
            const SizedBox(height: 32),

            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Última actualización: Enero 2026',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.6,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.justify,
          ),
        ],
      ),
    );
  }
}
