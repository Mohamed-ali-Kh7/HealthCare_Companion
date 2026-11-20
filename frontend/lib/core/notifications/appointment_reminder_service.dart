import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/appointment.dart';
import '../../services/appointment_service.dart';
import 'appointment_reminder_plan.dart';
import 'reminder_service.dart';

/// Rappels de rendez-vous (patient et médecin) : la veille à 18 h et 1 h avant.
///
/// - Téléphone : notifications système planifiées, reçues même application fermée.
/// - Toutes plateformes (dont le web) : bannière dans l'application quand l'heure du rappel arrive,
///   ou à l'ouverture si elle est passée et que le rendez-vous n'a pas encore commencé.
/// Chaque rappel n'est affiché qu'une fois (mémorisé sur l'appareil).
class AppointmentReminderService {
  AppointmentReminderService(this._appointments, this._notifications);

  final AppointmentService _appointments;
  final ReminderService _notifications;

  static const _shownKey = 'appointment_reminders_shown';
  static const _refreshEvery = Duration(minutes: 10);
  static const _checkEvery = Duration(seconds: 30);

  final _due = StreamController<AppointmentReminder>.broadcast();
  Timer? _refreshTimer;
  Timer? _checkTimer;
  bool? _forDoctor;
  List<AppointmentReminder> _reminders = const [];
  Set<String> _shown = {};

  /// Rappels à afficher maintenant dans l'application.
  Stream<AppointmentReminder> get due => _due.stream;

  /// Démarré à l'ouverture de l'espace patient ou médecin.
  Future<void> start({required bool forDoctor}) async {
    if (_forDoctor == forDoctor && _refreshTimer != null) return;
    stop();
    _forDoctor = forDoctor;
    final prefs = await SharedPreferences.getInstance();
    _shown = (prefs.getStringList(_shownKey) ?? const []).toSet();
    await refresh();
    _refreshTimer = Timer.periodic(_refreshEvery, (_) => refresh());
    _checkTimer = Timer.periodic(_checkEvery, (_) => _checkDue());
  }

  /// Recharge les rendez-vous et replanifie (après une réservation, une annulation, une acceptation...).
  Future<void> refresh() async {
    final forDoctor = _forDoctor;
    if (forDoctor == null) return;
    try {
      final now = DateTime.now();
      final List<Appointment> list = forDoctor
          ? await _appointments.getDoctorAppointments(
              status: AppointmentStatus.accepted, from: DateTime(now.year, now.month, now.day))
          : await _appointments.getMine();
      if (_forDoctor != forDoctor) return; // déconnecté entre-temps
      _reminders = AppointmentReminderPlan.compute(list, now, forDoctor: forDoctor);
      await _notifications.syncAppointments(_reminders);
      _checkDue();
    } catch (e) {
      debugPrint('Rappels de rendez-vous non mis à jour : $e');
    }
  }

  void _checkDue() {
    final now = DateTime.now();
    // Si les deux rappels d'un RDV sont dus (application ouverte tard), seul le plus proche est affiché
    final dueNow = _reminders.where((r) => r.isDue(now) && !_shown.contains(r.key)).toList()
      ..sort((a, b) => b.kind.index.compareTo(a.kind.index));
    final seen = <int>{};
    for (final r in dueNow) {
      _shown.add(r.key);
      if (seen.add(r.appointment.id)) _due.add(r);
    }
    if (dueNow.isNotEmpty) _saveShown();
  }

  Future<void> _saveShown() async {
    final prefs = await SharedPreferences.getInstance();
    // Ne garde que les rappels encore utiles (évite de grossir indéfiniment)
    final live = _reminders.map((r) => r.key).toSet();
    _shown.retainWhere(live.contains);
    await prefs.setStringList(_shownKey, _shown.toList());
  }

  /// Déconnexion : plus aucun rappel (les notifications système sont annulées par ReminderService.cancelAll).
  void stop() {
    _refreshTimer?.cancel();
    _checkTimer?.cancel();
    _refreshTimer = null;
    _checkTimer = null;
    _forDoctor = null;
    _reminders = const [];
  }

  void dispose() {
    stop();
    _due.close();
  }
}
