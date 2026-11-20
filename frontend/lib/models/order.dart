import 'package:flutter/material.dart';

import '../core/utils/formatters.dart';
import 'medicine.dart';
import 'pharmacy.dart';

enum OrderType {
  reservation('RESERVATION', 'Réservation', Icons.storefront),
  delivery('DELIVERY', 'Commande en ligne', Icons.local_shipping);

  const OrderType(this.apiValue, this.label, this.icon);

  final String apiValue;
  final String label;
  final IconData icon;

  static OrderType fromApi(String value) => OrderType.values.firstWhere((t) => t.apiValue == value);
}

enum OrderStatus {
  pending('PENDING', Colors.orange),
  confirmed('CONFIRMED', Colors.green),
  completed('COMPLETED', Colors.blueGrey),
  rejected('REJECTED', Colors.red),
  cancelled('CANCELLED', Colors.grey);

  const OrderStatus(this.apiValue, this.color);

  final String apiValue;
  final Color color;

  static OrderStatus fromApi(String value) => OrderStatus.values.firstWhere((s) => s.apiValue == value);
}

class OrderPatientInfo {
  const OrderPatientInfo({required this.id, required this.firstName, required this.lastName, this.phone});

  final int id;
  final String firstName;
  final String lastName;
  final String? phone;

  String get fullName => '$firstName $lastName';

  factory OrderPatientInfo.fromJson(Map<String, dynamic> json) => OrderPatientInfo(
        id: json['id'] as int,
        firstName: json['firstName'] as String,
        lastName: json['lastName'] as String,
        phone: json['phone'] as String?,
      );
}

/// Réservation (retrait en pharmacie) ou commande en ligne (livraison, paiement à la livraison).
class MedicineOrder {
  const MedicineOrder({
    required this.id,
    required this.type,
    required this.status,
    required this.quantity,
    required this.createdAt,
    required this.medicine,
    required this.pharmacy,
    required this.patient,
    this.unitPrice,
    this.totalPrice,
    this.deliveryAddress,
    this.phone,
    this.note,
    this.pharmacistNote,
  });

  final int id;
  final OrderType type;
  final OrderStatus status;
  final int quantity;
  final double? unitPrice;
  final double? totalPrice;
  final String? deliveryAddress;
  final String? phone;
  final String? note;
  final String? pharmacistNote;
  final DateTime createdAt;
  final Medicine medicine;
  final Pharmacy pharmacy;
  final OrderPatientInfo patient;

  bool get isDelivery => type == OrderType.delivery;
  bool get isOpen => status == OrderStatus.pending || status == OrderStatus.confirmed;

  /// Libellé du statut selon le type (une réservation confirmée est « prête », une commande « en livraison »).
  String get statusLabel => switch (status) {
        OrderStatus.pending => 'En attente de la pharmacie',
        OrderStatus.confirmed => isDelivery ? 'Confirmée · en livraison' : 'Prête à retirer',
        OrderStatus.completed => isDelivery ? 'Livrée' : 'Retirée',
        OrderStatus.rejected => 'Refusée',
        OrderStatus.cancelled => 'Annulée',
      };

  factory MedicineOrder.fromJson(Map<String, dynamic> json) => MedicineOrder(
        id: json['id'] as int,
        type: OrderType.fromApi(json['type'] as String),
        status: OrderStatus.fromApi(json['status'] as String),
        quantity: json['quantity'] as int,
        unitPrice: (json['unitPrice'] as num?)?.toDouble(),
        totalPrice: (json['totalPrice'] as num?)?.toDouble(),
        deliveryAddress: json['deliveryAddress'] as String?,
        phone: json['phone'] as String?,
        note: json['note'] as String?,
        pharmacistNote: json['pharmacistNote'] as String?,
        createdAt: ApiDates.parseInstant(json['createdAt']) ?? DateTime.now(),
        medicine: Medicine.fromJson(json['medicine'] as Map<String, dynamic>),
        pharmacy: Pharmacy.fromJson(json['pharmacy'] as Map<String, dynamic>),
        patient: OrderPatientInfo.fromJson(json['patient'] as Map<String, dynamic>),
      );
}
