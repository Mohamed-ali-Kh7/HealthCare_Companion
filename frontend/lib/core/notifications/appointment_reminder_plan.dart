import '../../models/appointment.dart';
import '../utils/formatters.dart';

enum AppointmentReminderKind { dayBefore, oneHourBefore }

/// Un rappel de rendez-vous à afficher à [at] (notification système et bannière dans l'application).
class AppointmentReminder {
  const AppointmentReminder({
    required this.appointment,
    required this.kind,
    required this.at,
    required this.title,
    required this.body,
  });

  final Appointment appointment;
  final AppointmentReminderKind kind;
  final DateTime at;
  final String title;
  final String body;

  /// Identifiant de notification : plage réservée aux rendez-vous (les médicaments utilisent 0 à 99 999).
  int get notificationId => AppointmentReminderPlan.idBase + appointment.id * 2 + kind.index;

  /// Clé « déjà affiché » : inclut l'heure du RDV pour qu'un rendez-vous déplacé soit rappelé à nouveau.
  String get key => '${appointment.id}:${kind.name}:${appointment.date.toIso8601String()}';

  /// À afficher maintenant : l'heure du rappel est passée mais pas encore le moment où il devient inutile.
  bool isDue(DateTime now) => !now.isBefore(at) && now.isBefore(_expiresAt);

  /// La veille n'a plus de sens une fois le rappel « 1 h avant » arrivé ; celui-ci expire au début du RDV.
  DateTime get _expiresAt => kind == AppointmentReminderKind.dayBefore
      ? appointment.date.subtract(AppointmentReminderPlan.lastReminderOffset)
      : appointment.date;
}

/// Rappels : la veille à 18 h et 1 h avant, pour les rendez-vous acceptés à venir.
class AppointmentReminderPlan {
  AppointmentReminderPlan._();

  static const idBase = 100000;
  static const dayBeforeHour = 18;
  static const lastReminderOffset = Duration(hours: 1);

  static List<AppointmentReminder> compute(List<Appointment> appointments, DateTime now, {required bool forDoctor}) {
    final reminders = <AppointmentReminder>[];
    for (final a in appointments) {
      if (a.status != AppointmentStatus.accepted || !a.date.isAfter(now)) continue;

      final eve = DateTime(a.date.year, a.date.month, a.date.day - 1, dayBeforeHour);
      final hourBefore = a.date.subtract(lastReminderOffset);
      final time = Fmt.time(a.date);
      final who = forDoctor ? a.patient.fullName : a.doctor.fullName;
      final where = forDoctor ? (a.reason == null ? '' : ' · Motif : ${a.reason}') : ' · ${a.doctor.address}';

      reminders.add(AppointmentReminder(
        appointment: a,
        kind: AppointmentReminderKind.dayBefore,
        at: eve,
        title: forDoctor ? 'Consultation demain à $time' : 'Rendez-vous demain à $time',
        body: forDoctor ? '$who$where' : 'Avec $who (${a.doctor.specialityName})$where',
      ));
      reminders.add(AppointmentReminder(
        appointment: a,
        kind: AppointmentReminderKind.oneHourBefore,
        at: hourBefore,
        title: forDoctor ? 'Consultation dans 1 h ($time)' : 'Rendez-vous dans 1 h ($time)',
        body: forDoctor ? '$who$where' : 'Avec $who$where',
      ));
    }
    return reminders;
  }
}
