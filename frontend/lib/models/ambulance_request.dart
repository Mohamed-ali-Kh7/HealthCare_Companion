import 'package:flutter/material.dart';

import '../core/utils/formatters.dart';
import 'patient.dart';

enum AmbulanceRequestType {
  emergency('EMERGENCY', 'Urgence'),
  scheduled('SCHEDULED', 'Transport programmé');

  const AmbulanceRequestType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static AmbulanceRequestType fromApi(String value) =>
      AmbulanceRequestType.values.firstWhere((t) => t.apiValue == value);
}

enum AmbulanceRequestStatus {
  pending('PENDING', 'En attente', Colors.orange),
  approved('APPROVED', 'Validé', Colors.green),
  rejected('REJECTED', 'Refusé', Colors.red),
  dispatched('DISPATCHED', 'En cours', Colors.deepOrange),
  closed('CLOSED', 'Terminé', Colors.blueGrey),
  cancelled('CANCELLED', 'Annulé', Colors.grey);

  const AmbulanceRequestStatus(this.apiValue, this.label, this.color);

  final String apiValue;
  final String label;
  final Color color;

  static AmbulanceRequestStatus fromApi(String value) =>
      AmbulanceRequestStatus.values.firstWhere((s) => s.apiValue == value);
}

/// Informations du patient utiles aux secours.
class AmbulancePatientInfo {
  const AmbulancePatientInfo({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.phone,
    this.bloodGroup,
    this.allergies,
  });

  final int id;
  final String firstName;
  final String lastName;
  final String? phone;
  final String? bloodGroup;
  final String? allergies;

  String get fullName => '$firstName $lastName';

  factory AmbulancePatientInfo.fromJson(Map<String, dynamic> json) =>
      AmbulancePatientInfo(
        id: json['id'] as int,
        firstName: json['firstName'] as String,
        lastName: json['lastName'] as String,
        phone: json['phone'] as String?,
        bloodGroup: json['bloodGroup'] as String?,
        allergies: json['allergies'] as String?,
      );
}

class AmbulanceRequest {
  const AmbulanceRequest({
    required this.id,
    required this.type,
    required this.status,
    required this.createdAt,
    required this.patient,
    this.latitude,
    this.longitude,
    this.address,
    this.reason,
    this.scheduledAt,
    this.doctorNote,
    this.doctor,
    this.mission,
  });

  final int id;
  final AmbulanceRequestType type;
  final AmbulanceRequestStatus status;
  final DateTime createdAt;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String? reason;
  final DateTime? scheduledAt;
  final String? doctorNote;
  final AmbulancePatientInfo patient;
  final PersonSummary? doctor;

  /// Société d'ambulance conventionnée chargée du transport (null tant qu'il n'est pas confié).
  final TransportMission? mission;

  /// Transport validé par le médecin, à confier (ou à reconfier après un refus) à une société conventionnée.
  bool get canChooseCompany =>
      type == AmbulanceRequestType.scheduled &&
      status == AmbulanceRequestStatus.approved &&
      (mission == null || mission!.status == MissionStatus.refused || mission!.status == MissionStatus.requested) &&
      (scheduledAt?.isAfter(DateTime.now()) ?? false);

  bool get isEmergency => type == AmbulanceRequestType.emergency;

  bool get hasLocation => latitude != null && longitude != null;

  /// Urgence en cours ou transport validé.
  bool get isOngoing =>
      status == AmbulanceRequestStatus.dispatched ||
      status == AmbulanceRequestStatus.approved;

  /// Clôture par le patient ou le médecin (même règle que le backend) : impossible dès qu'une société
  /// a affecté un véhicule, c'est elle qui clôture le transport à l'arrivée.
  bool get canBeClosed => isOngoing && !(mission?.status.inProgress ?? false);

  bool get canBeCancelled => !(mission?.status.started ?? false) && _cancellable;

  bool get _cancellable => isEmergency
      ? status == AmbulanceRequestStatus.dispatched
      : (status == AmbulanceRequestStatus.pending ||
              status == AmbulanceRequestStatus.approved) &&
          (scheduledAt?.isAfter(DateTime.now()) ?? false);

  factory AmbulanceRequest.fromJson(Map<String, dynamic> json) =>
      AmbulanceRequest(
        id: json['id'] as int,
        type: AmbulanceRequestType.fromApi(json['type'] as String),
        status: AmbulanceRequestStatus.fromApi(json['status'] as String),
        createdAt: ApiDates.parseInstant(json['createdAt'])!,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        address: json['address'] as String?,
        reason: json['reason'] as String?,
        scheduledAt: ApiDates.parseLocal(json['scheduledAt']),
        doctorNote: json['doctorNote'] as String?,
        patient: AmbulancePatientInfo.fromJson(
            json['patient'] as Map<String, dynamic>),
        doctor: json['doctor'] == null
            ? null
            : PersonSummary.fromJson(json['doctor'] as Map<String, dynamic>),
        mission: json['mission'] == null
            ? null
            : TransportMission.fromJson(json['mission'] as Map<String, dynamic>),
      );
}

/// Étapes d'un transport réalisé par une société conventionnée.
enum MissionStatus {
  requested('REQUESTED', 'En attente de la société', Icons.hourglass_top, Colors.orange),
  refused('REFUSED', 'Refusé par la société', Icons.block, Colors.red),
  accepted('ACCEPTED', 'Accepté, véhicule affecté', Icons.check_circle_outline, Colors.green),
  enRoute('EN_ROUTE', 'Ambulance en route', Icons.directions_car, Colors.blue),
  onSite('ON_SITE', 'Ambulance sur place', Icons.place, Colors.indigo),
  inTransit('IN_TRANSIT', 'Transport en cours', Icons.airport_shuttle, Colors.deepPurple),
  arrived('ARRIVED', 'Arrivé à destination', Icons.flag, Colors.blueGrey);

  const MissionStatus(this.apiValue, this.label, this.icon, this.color);

  final String apiValue;
  final String label;
  final IconData icon;
  final Color color;

  static MissionStatus fromApi(String value) => MissionStatus.values.firstWhere((s) => s.apiValue == value);

  /// Étapes du trajet, dans l'ordre (pour la frise de suivi).
  static const journey = [accepted, enRoute, onSite, inTransit, arrived];

  /// Le véhicule est parti : plus d'annulation possible depuis l'application.
  bool get started => this == enRoute || this == onSite || this == inTransit || this == arrived;

  /// Véhicule affecté et trajet non terminé : la société est engagée sur le transport.
  bool get inProgress => this == accepted || this == enRoute || this == onSite || this == inTransit;

  /// Libellé du bouton qui passe à l'étape suivante (côté société), ou null.
  String? get nextActionLabel => switch (this) {
        accepted => 'Départ : en route',
        enRoute => 'Arrivé chez le patient',
        onSite => 'Patient à bord',
        inTransit => 'Arrivé à destination',
        _ => null,
      };
}

class MissionCompany {
  const MissionCompany({required this.id, required this.name, required this.phone, this.conventionNumber, this.city});

  final int id;
  final String name;
  final String phone;
  final String? conventionNumber;
  final String? city;

  factory MissionCompany.fromJson(Map<String, dynamic> json) => MissionCompany(
        id: json['id'] as int,
        name: json['name'] as String,
        phone: json['phone'] as String,
        conventionNumber: json['conventionNumber'] as String?,
        city: json['city'] as String?,
      );
}

class MissionVehicle {
  const MissionVehicle({required this.id, required this.plate, required this.typeLabel, this.driverName, this.driverPhone});

  final int id;
  final String plate;
  final String typeLabel;
  final String? driverName;
  final String? driverPhone;

  factory MissionVehicle.fromJson(Map<String, dynamic> json) => MissionVehicle(
        id: json['id'] as int,
        plate: json['plate'] as String,
        typeLabel: json['typeLabel'] as String,
        driverName: json['driverName'] as String?,
        driverPhone: json['driverPhone'] as String?,
      );
}

class TransportMission {
  const TransportMission({required this.status, required this.company, this.vehicle, this.note, this.updatedAt});

  final MissionStatus status;
  final MissionCompany company;
  final MissionVehicle? vehicle;
  final String? note;
  final DateTime? updatedAt;

  factory TransportMission.fromJson(Map<String, dynamic> json) => TransportMission(
        status: MissionStatus.fromApi(json['status'] as String),
        company: MissionCompany.fromJson(json['company'] as Map<String, dynamic>),
        vehicle: json['vehicle'] == null ? null : MissionVehicle.fromJson(json['vehicle'] as Map<String, dynamic>),
        note: json['note'] as String?,
        updatedAt: ApiDates.parseInstant(json['updatedAt']),
      );
}
