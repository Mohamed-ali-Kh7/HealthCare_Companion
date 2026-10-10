import '../core/utils/formatters.dart';
import 'medicine.dart';

/// Traitement du carnet de suivi patient (issu d'une ordonnance ou ajouté manuellement).
class Medication {
  const Medication({
    required this.id,
    required this.medicine,
    required this.actualDosage,
    required this.timesPerDay,
    required this.startDate,
    required this.reminderTimes,
    required this.active,
    required this.ongoing,
    required this.fromPrescription,
    this.endDate,
  });

  final int id;
  final Medicine medicine;
  final String actualDosage;
  final int timesPerDay;
  final DateTime startDate;
  final DateTime? endDate;

  /// Heures "HH:mm"
  final List<String> reminderTimes;
  final bool active;
  final bool ongoing;
  final bool fromPrescription;

  factory Medication.fromJson(Map<String, dynamic> json) => Medication(
        id: json['id'] as int,
        medicine: Medicine.fromJson(json['medicine'] as Map<String, dynamic>),
        actualDosage: json['actualDosage'] as String,
        timesPerDay: json['timesPerDay'] as int,
        startDate: ApiDates.parseLocal(json['startDate'])!,
        endDate: ApiDates.parseLocal(json['endDate']),
        reminderTimes: (json['reminderTimes'] as List)
            .map((t) => (t as String).substring(0, 5))
            .toList(),
        active: json['active'] as bool,
        ongoing: json['ongoing'] as bool,
        fromPrescription: json['fromPrescription'] as bool,
      );
}
