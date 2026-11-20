import '../core/utils/formatters.dart';
import 'appointment.dart';

typedef DailyPoint = ({DateTime date, double value});

Map<String, int> _intMap(dynamic json) => (json as Map<String, dynamic>)
    .map((k, v) => MapEntry(k, (v as num).toInt()));

/// Statistiques personnelles du patient (/api/stats/patient).
class PatientStats {
  const PatientStats({
    required this.appointmentsByStatus,
    required this.doctorsConsulted,
    required this.ongoingMedications,
    required this.prescriptions,
    required this.ambulanceRequests,
    required this.activity,
    this.nextAppointment,
  });

  final Map<String, int> appointmentsByStatus;
  final Appointment? nextAppointment;
  final int doctorsConsulted;
  final int ongoingMedications;
  final int prescriptions;
  final int ambulanceRequests;
  final PatientActivity activity;

  factory PatientStats.fromJson(Map<String, dynamic> json) => PatientStats(
        appointmentsByStatus: _intMap(json['appointmentsByStatus']),
        nextAppointment: json['nextAppointment'] == null
            ? null
            : Appointment.fromJson(
                json['nextAppointment'] as Map<String, dynamic>),
        doctorsConsulted: json['doctorsConsulted'] as int,
        ongoingMedications: json['ongoingMedications'] as int,
        prescriptions: json['prescriptions'] as int,
        ambulanceRequests: json['ambulanceRequests'] as int,
        activity:
            PatientActivity.fromJson(json['activity'] as Map<String, dynamic>),
      );
}

/// Activité des 7 derniers jours. Les moyennes ne comptent que les jours mesurés.
class PatientActivity {
  const PatientActivity({
    required this.stepsToday,
    required this.averageDailySteps,
    required this.bestDaySteps,
    required this.daysWithSteps,
    required this.stepsPerDay,
    this.bestDay,
    this.averageHeartRate,
  });

  final int stepsToday;
  final int averageDailySteps;
  final DateTime? bestDay;
  final int bestDaySteps;
  final int daysWithSteps;
  final double? averageHeartRate;
  final List<DailyPoint> stepsPerDay;

  factory PatientActivity.fromJson(Map<String, dynamic> json) =>
      PatientActivity(
        stepsToday: json['stepsToday'] as int,
        averageDailySteps: json['averageDailySteps'] as int,
        bestDay: ApiDates.parseLocal(json['bestDay']),
        bestDaySteps: json['bestDaySteps'] as int,
        daysWithSteps: json['daysWithSteps'] as int,
        averageHeartRate: (json['averageHeartRate'] as num?)?.toDouble(),
        stepsPerDay: [
          for (final e in json['stepsPerDay'] as List)
            (
              date: ApiDates.parseLocal((e as Map<String, dynamic>)['date'])!,
              value: (e['value'] as num).toDouble(),
            ),
        ],
      );
}

class MedicineUsage {
  const MedicineUsage({required this.name, required this.count, this.strength});

  final String name;
  final String? strength;
  final int count;

  String get label => strength == null ? name : '$name $strength';

  factory MedicineUsage.fromJson(Map<String, dynamic> json) => MedicineUsage(
        name: json['name'] as String,
        strength: json['strength'] as String?,
        count: json['count'] as int,
      );
}

/// Statistiques d'activité du médecin (/api/stats/doctor).
class DoctorStats {
  const DoctorStats({
    required this.patientsFollowed,
    required this.appointmentsByStatus,
    required this.appointmentsToday,
    required this.upcomingPerDay,
    required this.consultationsThisMonth,
    required this.prescriptionsIssued,
    required this.prescriptionsThisMonth,
    required this.topMedicines,
    required this.pendingTransportValidations,
    required this.activeEmergencies,
    this.acceptanceRate,
  });

  final int patientsFollowed;
  final Map<String, int> appointmentsByStatus;
  final int appointmentsToday;
  final List<DailyPoint> upcomingPerDay;

  /// En %, null tant qu'aucune demande n'a été traitée.
  final double? acceptanceRate;
  final int consultationsThisMonth;
  final int prescriptionsIssued;
  final int prescriptionsThisMonth;
  final List<MedicineUsage> topMedicines;
  final int pendingTransportValidations;
  final int activeEmergencies;

  factory DoctorStats.fromJson(Map<String, dynamic> json) => DoctorStats(
        patientsFollowed: json['patientsFollowed'] as int,
        appointmentsByStatus: _intMap(json['appointmentsByStatus']),
        appointmentsToday: json['appointmentsToday'] as int,
        upcomingPerDay: [
          for (final e in json['upcomingPerDay'] as List)
            (
              date: ApiDates.parseLocal((e as Map<String, dynamic>)['date'])!,
              value: (e['count'] as num).toDouble(),
            ),
        ],
        acceptanceRate: (json['acceptanceRate'] as num?)?.toDouble(),
        consultationsThisMonth: json['consultationsThisMonth'] as int,
        prescriptionsIssued: json['prescriptionsIssued'] as int,
        prescriptionsThisMonth: json['prescriptionsThisMonth'] as int,
        topMedicines: [
          for (final e in json['topMedicines'] as List)
            MedicineUsage.fromJson(e as Map<String, dynamic>),
        ],
        pendingTransportValidations: json['pendingTransportValidations'] as int,
        activeEmergencies: json['activeEmergencies'] as int,
      );
}
