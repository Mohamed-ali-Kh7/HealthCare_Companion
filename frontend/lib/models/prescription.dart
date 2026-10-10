import '../core/utils/formatters.dart';
import 'medicine.dart';
import 'patient.dart';

class PrescriptionItem {
  const PrescriptionItem({
    required this.id,
    required this.medicine,
    required this.prescribedDosage,
    required this.timesPerDay,
    required this.durationDays,
    this.instructions,
  });

  final int id;
  final Medicine medicine;
  final String prescribedDosage;
  final int timesPerDay;
  final int durationDays;
  final String? instructions;

  /// Ex : "1 comprimé · 3 fois/jour · 5 jours"
  String get posology => '$prescribedDosage · $timesPerDay fois/jour · $durationDays jours';

  factory PrescriptionItem.fromJson(Map<String, dynamic> json) => PrescriptionItem(
        id: json['id'] as int,
        medicine: Medicine.fromJson(json['medicine'] as Map<String, dynamic>),
        prescribedDosage: json['prescribedDosage'] as String,
        timesPerDay: json['timesPerDay'] as int,
        durationDays: json['durationDays'] as int,
        instructions: json['instructions'] as String?,
      );
}

class Prescription {
  const Prescription({
    required this.id,
    required this.date,
    required this.patient,
    required this.doctorName,
    required this.doctorSpeciality,
    required this.items,
    this.notes,
  });

  final int id;
  final DateTime date;
  final String? notes;
  final PersonSummary patient;
  final String doctorName;
  final String doctorSpeciality;
  final List<PrescriptionItem> items;

  factory Prescription.fromJson(Map<String, dynamic> json) {
    final doctor = json['doctor'] as Map<String, dynamic>;
    return Prescription(
      id: json['id'] as int,
      date: ApiDates.parseLocal(json['prescriptionDate'])!,
      notes: json['notes'] as String?,
      patient: PersonSummary.fromJson(json['patient'] as Map<String, dynamic>),
      doctorName: 'Dr ${doctor['firstName']} ${doctor['lastName']}',
      doctorSpeciality: doctor['specialityName'] as String,
      items: (json['items'] as List)
          .map((e) => PrescriptionItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Ligne en cours de saisie par le médecin (formulaire d'ordonnance).
class PrescriptionItemDraft {
  PrescriptionItemDraft({
    required this.medicine,
    this.prescribedDosage = '1 comprimé',
    this.timesPerDay = 1,
    this.durationDays = 7,
    this.instructions = '',
  });

  Medicine medicine;
  String prescribedDosage;
  int timesPerDay;
  int durationDays;
  String instructions;

  Map<String, dynamic> toJson() => {
        'medicineId': medicine.id,
        'prescribedDosage': prescribedDosage,
        'timesPerDay': timesPerDay,
        'durationDays': durationDays,
        'instructions': instructions.isEmpty ? null : instructions,
      };
}
