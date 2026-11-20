import 'speciality.dart';

class Doctor {
  const Doctor({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.address,
    required this.speciality,
    required this.consultationDurationMinutes,
    this.phone,
    this.bio,
    this.away = false,
    this.awayMessage,
    this.awayUntil,
  });

  final int id;
  final String firstName;
  final String lastName;
  final String? phone;
  final String address;
  final String? bio;
  final int consultationDurationMinutes;
  final Speciality speciality;

  /// Absent / indisponible (visible dans la messagerie des patients).
  final bool away;
  final String? awayMessage;
  final DateTime? awayUntil;

  String get fullName => 'Dr $firstName $lastName';

  factory Doctor.fromJson(Map<String, dynamic> json) => Doctor(
        id: json['id'] as int,
        firstName: json['firstName'] as String,
        lastName: json['lastName'] as String,
        phone: json['phone'] as String?,
        address: json['address'] as String,
        bio: json['bio'] as String?,
        consultationDurationMinutes: json['consultationDurationMinutes'] as int,
        speciality: Speciality.fromJson(json['speciality'] as Map<String, dynamic>),
        away: json['away'] as bool? ?? false,
        awayMessage: json['awayMessage'] as String?,
        awayUntil: json['awayUntil'] == null ? null : DateTime.parse(json['awayUntil'] as String),
      );
}

/// Jours de la semaine tels qu'attendus par l'API (java.time.DayOfWeek).
const weekDays = <String, String>{
  'MONDAY': 'Lundi',
  'TUESDAY': 'Mardi',
  'WEDNESDAY': 'Mercredi',
  'THURSDAY': 'Jeudi',
  'FRIDAY': 'Vendredi',
  'SATURDAY': 'Samedi',
  'SUNDAY': 'Dimanche',
};

/// Plage hebdomadaire du planning (ex : lundi 09:00-12:00).
class Availability {
  const Availability({
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
  });

  final String dayOfWeek;

  /// Format "HH:mm"
  final String startTime;
  final String endTime;

  String get dayLabel => weekDays[dayOfWeek] ?? dayOfWeek;

  factory Availability.fromJson(Map<String, dynamic> json) => Availability(
        dayOfWeek: json['dayOfWeek'] as String,
        startTime: (json['startTime'] as String).substring(0, 5),
        endTime: (json['endTime'] as String).substring(0, 5),
      );

  Map<String, dynamic> toJson() => {'dayOfWeek': dayOfWeek, 'startTime': startTime, 'endTime': endTime};
}
