import 'package:flutter/material.dart';

import '../core/utils/formatters.dart';
import 'patient.dart';

enum AppointmentStatus {
  pending('PENDING', 'En attente', Colors.orange),
  accepted('ACCEPTED', 'Accepté', Colors.green),
  rejected('REJECTED', 'Refusé', Colors.red),
  completed('COMPLETED', 'Terminé', Colors.blueGrey),
  cancelled('CANCELLED', 'Annulé', Colors.grey);

  const AppointmentStatus(this.apiValue, this.label, this.color);

  final String apiValue;
  final String label;
  final Color color;

  static AppointmentStatus fromApi(String value) =>
      AppointmentStatus.values.firstWhere((s) => s.apiValue == value);
}

class AppointmentDoctor {
  const AppointmentDoctor({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.specialityName,
    required this.address,
  });

  final int id;
  final String firstName;
  final String lastName;
  final String specialityName;
  final String address;

  String get fullName => 'Dr $firstName $lastName';

  factory AppointmentDoctor.fromJson(Map<String, dynamic> json) => AppointmentDoctor(
        id: json['id'] as int,
        firstName: json['firstName'] as String,
        lastName: json['lastName'] as String,
        specialityName: json['specialityName'] as String,
        address: json['address'] as String,
      );
}

class Appointment {
  const Appointment({
    required this.id,
    required this.date,
    required this.status,
    required this.patient,
    required this.doctor,
    this.reason,
    this.doctorNote,
  });

  final int id;
  final DateTime date;
  final AppointmentStatus status;
  final String? reason;
  final String? doctorNote;
  final PersonSummary patient;
  final AppointmentDoctor doctor;

  bool get isUpcoming => date.isAfter(DateTime.now());

  bool get canBeCancelled =>
      isUpcoming &&
      (status == AppointmentStatus.pending || status == AppointmentStatus.accepted);

  factory Appointment.fromJson(Map<String, dynamic> json) => Appointment(
        id: json['id'] as int,
        date: ApiDates.parseLocal(json['appointmentDate'])!,
        status: AppointmentStatus.fromApi(json['status'] as String),
        reason: json['reason'] as String?,
        doctorNote: json['doctorNote'] as String?,
        patient: PersonSummary.fromJson(json['patient'] as Map<String, dynamic>),
        doctor: AppointmentDoctor.fromJson(json['doctor'] as Map<String, dynamic>),
      );
}
