import '../core/utils/formatters.dart';

class Patient {
  const Patient({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.phone,
    this.dateOfBirth,
    this.bloodGroup,
    this.allergies,
  });

  final int id;
  final String email;
  final String firstName;
  final String lastName;
  final String? phone;
  final DateTime? dateOfBirth;
  final String? bloodGroup;
  final String? allergies;

  String get fullName => '$firstName $lastName';

  int? get age {
    final dob = dateOfBirth;
    if (dob == null) return null;
    final now = DateTime.now();
    var years = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) years--;
    return years;
  }

  factory Patient.fromJson(Map<String, dynamic> json) => Patient(
        id: json['id'] as int,
        email: json['email'] as String,
        firstName: json['firstName'] as String,
        lastName: json['lastName'] as String,
        phone: json['phone'] as String?,
        dateOfBirth: ApiDates.parseLocal(json['dateOfBirth']),
        bloodGroup: json['bloodGroup'] as String?,
        allergies: json['allergies'] as String?,
      );
}

/// Résumé (id + nom) embarqué dans les rendez-vous et ordonnances.
class PersonSummary {
  const PersonSummary({required this.id, required this.firstName, required this.lastName});

  final int id;
  final String firstName;
  final String lastName;

  String get fullName => '$firstName $lastName';

  factory PersonSummary.fromJson(Map<String, dynamic> json) => PersonSummary(
        id: json['id'] as int,
        firstName: json['firstName'] as String,
        lastName: json['lastName'] as String,
      );
}
