/// Société d'ambulance conventionnée CNAM.
class AmbulanceCompany {
  const AmbulanceCompany({
    required this.id,
    required this.name,
    required this.conventionNumber,
    required this.address,
    required this.city,
    required this.phone,
    required this.latitude,
    required this.longitude,
    required this.serviceRadiusKm,
    required this.acceptingRequests,
    this.distanceKm,
    this.vehiclesInService,
  });

  final int id;
  final String name;
  final String conventionNumber;
  final String address;
  final String city;
  final String phone;
  final double latitude;
  final double longitude;
  final int serviceRadiusKm;
  final bool acceptingRequests;
  final double? distanceKm;
  final int? vehiclesInService;

  factory AmbulanceCompany.fromJson(Map<String, dynamic> json) => AmbulanceCompany(
        id: json['id'] as int,
        name: json['name'] as String,
        conventionNumber: json['conventionNumber'] as String,
        address: json['address'] as String,
        city: json['city'] as String,
        phone: json['phone'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        serviceRadiusKm: (json['serviceRadiusKm'] as num).toInt(),
        acceptingRequests: json['acceptingRequests'] as bool,
        distanceKm: (json['distanceKm'] as num?)?.toDouble(),
        vehiclesInService: (json['vehiclesInService'] as num?)?.toInt(),
      );
}

enum VehicleType {
  ambulance('AMBULANCE', 'Ambulance'),
  vsl('VSL', 'VSL (véhicule sanitaire léger)');

  const VehicleType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static VehicleType fromApi(String value) => VehicleType.values.firstWhere((t) => t.apiValue == value);
}

class AmbulanceVehicle {
  const AmbulanceVehicle({
    required this.id,
    required this.plate,
    required this.type,
    required this.inService,
    this.driverName,
    this.driverPhone,
  });

  final int id;
  final String plate;
  final VehicleType type;
  final bool inService;
  final String? driverName;
  final String? driverPhone;

  factory AmbulanceVehicle.fromJson(Map<String, dynamic> json) => AmbulanceVehicle(
        id: json['id'] as int,
        plate: json['plate'] as String,
        type: VehicleType.fromApi(json['type'] as String),
        inService: json['inService'] as bool,
        driverName: json['driverName'] as String?,
        driverPhone: json['driverPhone'] as String?,
      );
}
