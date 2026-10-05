import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    // Configurar zona horaria de Ecuador (GMT-5)
    tz.setLocalLocation(tz.getLocation('America/Guayaquil'));

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // Handle notification tap
      },
    );

    // Solicitar permisos en Android 13+
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'financial_control_channel',
          'Notificaciones de Chiroless',
          channelDescription: 'Canal para notificaciones de Chiroless',
          icon: 'ic_stat_chiroless',
          importance: Importance.max,
          priority: Priority.high,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
    );
  }

  Future<void> scheduleDailyReminder() async {
    // Cancelar notificaciones previas
    await cancelAllReminders();

    // Programar notificación de 1 PM
    await flutterLocalNotificationsPlugin.zonedSchedule(
      1, // ID único para la notificación de 1 PM
      '💰 Recordatorio de Chiroless',
      '¡No olvides anotar tus gastos o ingresos del día!',
      _nextInstanceOfTime(13, 0), // 1:00 PM
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder_channel',
          'Recordatorios Diarios',
          channelDescription: 'Recordatorios para registrar tus transacciones',
          icon: 'ic_stat_chiroless',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    // Programar notificación de 8 PM
    await flutterLocalNotificationsPlugin.zonedSchedule(
      2, // ID único para la notificación de 8 PM
      '📊 Revisa tu Chiroless',
      '¿Ya registraste todas tus transacciones de hoy?',
      _nextInstanceOfTime(20, 0), // 8:00 PM
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder_channel',
          'Recordatorios Diarios',
          channelDescription: 'Recordatorios para registrar tus transacciones',
          icon: 'ic_stat_chiroless',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    // Si la hora ya pasó hoy, programar para mañana
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  Future<void> cancelAllReminders() async {
    await flutterLocalNotificationsPlugin.cancel(1); // Cancelar 1 PM
    await flutterLocalNotificationsPlugin.cancel(2); // Cancelar 8 PM
  }

  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }
}
