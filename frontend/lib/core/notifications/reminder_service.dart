import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../models/medication.dart';
import '../config/app_config.dart';
import '../utils/formatters.dart';
import 'appointment_reminder_plan.dart';

/// Rappels de prise de médicaments : notifications locales quotidiennes,
/// planifiées sur le téléphone à partir des heures du carnet (aucun serveur push requis).
class ReminderService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'medication_reminders',
      'Rappels de médicaments',
      channelDescription: 'Rappels quotidiens de prise de traitement',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  Future<void> init() async {
    if (_initialized || kIsWeb) return; // pas de notifications locales sur le web
    try {
      tz_data.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation(AppConfig.timezone));
      await _plugin.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ));
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      _initialized = true;
    } catch (e) {
      debugPrint('Notifications indisponibles : $e');
    }
  }

  static const _appointmentDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'appointment_reminders',
      'Rappels de rendez-vous',
      channelDescription: 'La veille et 1 h avant chaque rendez-vous',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  /// Replanifie tous les rappels à partir du carnet (appelé après chaque chargement/modification).
  /// Ne touche pas aux rappels de rendez-vous (identifiants ≥ [AppointmentReminderPlan.idBase]).
  Future<int> syncWithMedications(List<Medication> medications) async {
    await init();
    if (!_initialized) return 0;

    await _cancelWhere((id) => id < AppointmentReminderPlan.idBase);
    final today = DateTime.now();
    var id = 0;
    for (final m in medications) {
      final finished = m.endDate != null &&
          DateTime(m.endDate!.year, m.endDate!.month, m.endDate!.day)
              .isBefore(DateTime(today.year, today.month, today.day));
      if (!m.active || finished) continue;

      for (final time in m.reminderTimes) {
        final t = ApiDates.parseTime(time);
        await _plugin.zonedSchedule(
          id++,
          'Prise de médicament',
          '${m.medicine.name} ${m.medicine.strength} — ${m.actualDosage}',
          _nextInstanceOf(t.hour, t.minute),
          _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time, // répétition quotidienne
        );
      }
    }
    return id;
  }

  /// Remplace les rappels de rendez-vous planifiés (notifications système, même application fermée).
  /// Sans effet sur le web : les notifications locales n'y existent pas (la bannière dans l'application prend le relais).
  Future<int> syncAppointments(List<AppointmentReminder> reminders) async {
    await init();
    if (!_initialized) return 0;

    await _cancelWhere((id) => id >= AppointmentReminderPlan.idBase);
    final now = DateTime.now();
    var count = 0;
    for (final r in reminders) {
      if (!r.at.isAfter(now)) continue; // déjà passé : la bannière s'en charge à l'ouverture
      await _plugin.zonedSchedule(
        r.notificationId,
        r.title,
        r.body,
        tz.TZDateTime(tz.local, r.at.year, r.at.month, r.at.day, r.at.hour, r.at.minute),
        _appointmentDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
      count++;
    }
    return count;
  }

  Future<void> cancelAll() async {
    if (_initialized) await _plugin.cancelAll();
  }

  Future<void> _cancelWhere(bool Function(int id) test) async {
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final p in pending.where((p) => test(p.id))) {
        await _plugin.cancel(p.id);
      }
    } catch (e) {
      debugPrint('Annulation sélective impossible : $e');
    }
  }

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
