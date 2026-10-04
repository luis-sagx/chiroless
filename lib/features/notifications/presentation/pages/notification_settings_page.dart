import 'package:flutter/material.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/theme/app_theme.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  final NotificationService _notificationService = NotificationService();
  bool _notificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración de Notificaciones')),
      body: ListView(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.primaryColor),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Recibe recordatorios diarios a la 1:00 PM y 8:00 PM (hora Ecuador) para no olvidar registrar tus gastos e ingresos.',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          SwitchListTile(
            title: const Text(
              'Recordatorios Diarios',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('Activa notificaciones automáticas'),
            value: _notificationsEnabled,
            activeColor: AppTheme.primaryColor,
            onChanged: (bool value) async {
              setState(() {
                _notificationsEnabled = value;
              });

              if (value) {
                await _notificationService.scheduleDailyReminder();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Notificaciones activadas: 1:00 PM y 8:00 PM',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } else {
                await _notificationService.cancelAllReminders();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Notificaciones desactivadas'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              }
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.schedule, color: AppTheme.primaryColor),
            title: const Text('Horario de Notificaciones'),
            subtitle: const Text('1:00 PM y 8:00 PM (hora Ecuador)'),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mensajes de Recordatorio:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildMessageCard(
                  '1:00 PM',
                  '💰 Recordatorio de Control Financiero',
                  '¡No olvides anotar tus gastos o ingresos del día!',
                ),
                const SizedBox(height: 8),
                _buildMessageCard(
                  '8:00 PM',
                  '📊 Revisa tu Control Financiero',
                  '¿Ya registraste todas tus transacciones de hoy?',
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildMessageCard(String time, String title, String body) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(body, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
          ],
        ),
      ),
    );
  }
}
