import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_companion/core/notifications/appointment_reminder_plan.dart';
import 'package:healthcare_companion/models/appointment.dart';
import 'package:intl/date_symbol_data_local.dart';

Appointment _appointment(int id, String date, {String status = 'ACCEPTED'}) => Appointment.fromJson({
      'id': id,
      'appointmentDate': date,
      'status': status,
      'reason': 'Contrôle',
      'patient': {'id': 1, 'firstName': 'Amira', 'lastName': 'Ben Salah'},
      'doctor': {
        'id': 1,
        'firstName': 'Karim',
        'lastName': 'Trabelsi',
        'specialityName': 'Médecine générale',
        'address': '10 avenue Habib Bourguiba, Tunis',
      },
    });

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  final now = DateTime(2026, 11, 13, 9, 0);

  test('la veille à 18 h et 1 h avant, pour un RDV accepté', () {
    final r = AppointmentReminderPlan.compute([_appointment(5, '2026-11-14T10:30:00')], now, forDoctor: false);
    expect(r, hasLength(2));
    expect(r[0].kind, AppointmentReminderKind.dayBefore);
    expect(r[0].at, DateTime(2026, 11, 13, 18, 0));
    expect(r[0].title, 'Rendez-vous demain à 10:30');
    expect(r[0].body, contains('Dr Karim Trabelsi'));
    expect(r[1].at, DateTime(2026, 11, 14, 9, 30));
    expect(r[1].title, 'Rendez-vous dans 1 h (10:30)');
    expect(r[0].notificationId, isNot(r[1].notificationId));
    expect(r[0].notificationId, greaterThanOrEqualTo(AppointmentReminderPlan.idBase));
  });

  test('côté médecin : nom du patient et motif', () {
    final r = AppointmentReminderPlan.compute([_appointment(5, '2026-11-14T10:30:00')], now, forDoctor: true);
    expect(r[1].title, 'Consultation dans 1 h (10:30)');
    expect(r[1].body, 'Amira Ben Salah · Motif : Contrôle');
  });

  test('ignore les RDV en attente, refusés et passés', () {
    final r = AppointmentReminderPlan.compute([
      _appointment(1, '2026-11-14T10:00:00', status: 'PENDING'),
      _appointment(2, '2026-11-14T10:00:00', status: 'CANCELLED'),
      _appointment(3, '2026-11-12T10:00:00'),
    ], now, forDoctor: false);
    expect(r, isEmpty);
  });

  test('changement de mois pour la veille', () {
    final r = AppointmentReminderPlan.compute([_appointment(7, '2026-12-01T08:00:00')], now, forDoctor: false);
    expect(r[0].at, DateTime(2026, 11, 30, 18, 0));
  });

  test('fenêtre d\'affichage : la veille expire quand le rappel « 1 h avant » arrive', () {
    final r = AppointmentReminderPlan.compute([_appointment(5, '2026-11-14T10:30:00')], now, forDoctor: false);
    final eve = r[0], hour = r[1];
    expect(eve.isDue(DateTime(2026, 11, 13, 17, 59)), isFalse);
    expect(eve.isDue(DateTime(2026, 11, 13, 18, 0)), isTrue);
    expect(eve.isDue(DateTime(2026, 11, 14, 9, 30)), isFalse);
    expect(hour.isDue(DateTime(2026, 11, 14, 9, 45)), isTrue);
    expect(hour.isDue(DateTime(2026, 11, 14, 10, 30)), isFalse); // RDV commencé
  });
}
