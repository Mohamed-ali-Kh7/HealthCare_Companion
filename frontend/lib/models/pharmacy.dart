import '../core/utils/formatters.dart';
import 'medicine.dart';

class Pharmacy {
  const Pharmacy({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.onDuty,
    this.phone,
    this.openingHours,
    this.distanceKm,
  });

  final int id;
  final String name;
  final String address;
  final String? phone;
  final double latitude;
  final double longitude;
  final String? openingHours;
  final bool onDuty;
  final double? distanceKm;

  String get distanceLabel {
    final d = distanceKm;
    if (d == null) return '';
    return d < 1 ? '${(d * 1000).round()} m' : '${d.toStringAsFixed(1)} km';
  }

  factory Pharmacy.fromJson(Map<String, dynamic> json) => Pharmacy(
        id: json['id'] as int,
        name: json['name'] as String,
        address: json['address'] as String,
        phone: json['phone'] as String?,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        openingHours: json['openingHours'] as String?,
        onDuty: json['onDuty'] as bool,
        distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      );
}

/// Ligne d'inventaire d'une pharmacie.
class StockItem {
  const StockItem({
    required this.id,
    required this.medicine,
    required this.quantity,
    this.price,
    this.lastUpdated,
  });

  final int id;
  final Medicine medicine;
  final int quantity;
  final double? price;
  final DateTime? lastUpdated;

  factory StockItem.fromJson(Map<String, dynamic> json) => StockItem(
        id: json['id'] as int,
        medicine: Medicine.fromJson(json['medicine'] as Map<String, dynamic>),
        quantity: json['quantity'] as int,
        price: (json['price'] as num?)?.toDouble(),
        lastUpdated: ApiDates.parseInstant(json['lastUpdated']),
      );
}

/// Pharmacie proche ayant un médicament en stock.
class MedicineAvailability {
  const MedicineAvailability({required this.pharmacy, required this.quantity, this.price});

  final Pharmacy pharmacy;
  final int quantity;
  final double? price;

  factory MedicineAvailability.fromJson(Map<String, dynamic> json) => MedicineAvailability(
        pharmacy: Pharmacy.fromJson(json['pharmacy'] as Map<String, dynamic>),
        quantity: json['quantity'] as int,
        price: (json['price'] as num?)?.toDouble(),
      );
}
