import 'package:flutter/material.dart';

import '../core/utils/formatters.dart';

/// Prise en charge CNAM (simulée : aucune connexion réelle à la CNAM).
enum CnamCoverage {
  none('NONE', 'Sans prise en charge', 'Le patient paie la totalité'),
  privateSector('PRIVATE_SECTOR', 'Filière privée (tiers payant)',
      'Le patient ne paie que le ticket modérateur, la CNAM règle le reste au médecin'),
  reimbursement('REIMBURSEMENT', 'Système de remboursement',
      'Le patient paie tout puis se fait rembourser avec le bulletin de soins');

  const CnamCoverage(this.apiValue, this.label, this.help);

  final String apiValue;
  final String label;
  final String help;

  static CnamCoverage fromApi(String value) => CnamCoverage.values.firstWhere((c) => c.apiValue == value);
}

enum InvoiceStatus {
  unpaid('UNPAID', 'À payer', Colors.orange),
  paid('PAID', 'Payée', Colors.green);

  const InvoiceStatus(this.apiValue, this.label, this.color);

  final String apiValue;
  final String label;
  final Color color;

  static InvoiceStatus fromApi(String value) => InvoiceStatus.values.firstWhere((s) => s.apiValue == value);
}

/// Acte facturable et tarif proposé.
class CareActOption {
  const CareActOption({required this.code, required this.label, required this.suggestedFee});

  final String code;
  final String label;
  final double suggestedFee;

  factory CareActOption.fromJson(Map<String, dynamic> json) => CareActOption(
        code: json['code'] as String,
        label: json['label'] as String,
        suggestedFee: (json['suggestedFee'] as num).toDouble(),
      );
}

class InvoicePatient {
  const InvoicePatient({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.dateOfBirth,
    this.cnamNumber,
  });

  final int id;
  final String firstName;
  final String lastName;
  final DateTime? dateOfBirth;
  final String? cnamNumber;

  String get fullName => '$firstName $lastName';

  factory InvoicePatient.fromJson(Map<String, dynamic> json) => InvoicePatient(
        id: json['id'] as int,
        firstName: json['firstName'] as String,
        lastName: json['lastName'] as String,
        dateOfBirth: ApiDates.parseLocal(json['dateOfBirth']),
        cnamNumber: json['cnamNumber'] as String?,
      );
}

/// Émetteur de la facture : médecin (consultation) ou société d'ambulance conventionnée (transport).
class InvoiceIssuer {
  const InvoiceIssuer({
    required this.kind,
    required this.id,
    required this.name,
    required this.subtitle,
    this.address,
    this.phone,
  });

  /// DOCTOR ou AMBULANCE_COMPANY
  final String kind;
  final int id;

  /// « Dr Karim Trabelsi » ou « Ambulances Ennour »
  final String name;

  /// Spécialité du médecin, ou numéro de convention CNAM de la société.
  final String subtitle;
  final String? address;
  final String? phone;

  bool get isAmbulance => kind == 'AMBULANCE_COMPANY';

  factory InvoiceIssuer.fromJson(Map<String, dynamic> json) => InvoiceIssuer(
        kind: json['kind'] as String,
        id: json['id'] as int,
        name: json['name'] as String,
        subtitle: json['subtitle'] as String,
        address: json['address'] as String?,
        phone: json['phone'] as String?,
      );
}

/// Facture d'une consultation (médecin) ou d'un transport (ambulance conventionnée). Montants en dinars.
class Invoice {
  const Invoice({
    required this.id,
    required this.number,
    required this.issuedAt,
    required this.act,
    required this.actLabel,
    required this.amount,
    required this.coverage,
    required this.cnamRatePercent,
    required this.cnamShare,
    required this.patientDue,
    required this.status,
    required this.serviceDate,
    required this.patient,
    required this.issuer,
    this.appointmentId,
    this.ambulanceRequestId,
    this.cnamNumber,
    this.paidAt,
    this.paymentMethod,
    this.paymentReference,
    this.cardLast4,
    this.verifyUrl,
  });

  final int id;
  final String number;
  final DateTime issuedAt;
  final String act;
  final String actLabel;
  final double amount;
  final CnamCoverage coverage;
  final String? cnamNumber;
  final int cnamRatePercent;
  final double cnamShare;
  final double patientDue;
  final InvoiceStatus status;
  final DateTime? paidAt;
  final String? paymentMethod;
  final String? paymentReference;
  final String? cardLast4;
  final int? appointmentId;
  final int? ambulanceRequestId;

  /// Date des soins : consultation ou transport.
  final DateTime serviceDate;
  final InvoicePatient patient;
  final InvoiceIssuer issuer;

  bool get isTransport => ambulanceRequestId != null;
  final String? verifyUrl;

  bool get isPaid => status == InvoiceStatus.paid;

  String get paymentLabel => switch (paymentMethod) {
        'CARD' => 'Carte bancaire${cardLast4 == null ? '' : ' •••• $cardLast4'}',
        'CASH' => 'Espèces',
        _ => '—',
      };

  /// Remboursement attendu de la CNAM après dépôt du bulletin de soins.
  bool get expectsRefund => coverage == CnamCoverage.reimbursement && cnamShare > 0;

  factory Invoice.fromJson(Map<String, dynamic> json) => Invoice(
        id: json['id'] as int,
        number: json['number'] as String,
        issuedAt: ApiDates.parseInstant(json['issuedAt']) ?? DateTime.now(),
        act: json['act'] as String,
        actLabel: json['actLabel'] as String,
        amount: (json['amount'] as num).toDouble(),
        coverage: CnamCoverage.fromApi(json['coverage'] as String),
        cnamNumber: json['cnamNumber'] as String?,
        cnamRatePercent: (json['cnamRatePercent'] as num).toInt(),
        cnamShare: (json['cnamShare'] as num).toDouble(),
        patientDue: (json['patientDue'] as num).toDouble(),
        status: InvoiceStatus.fromApi(json['status'] as String),
        paidAt: ApiDates.parseInstant(json['paidAt']),
        paymentMethod: json['paymentMethod'] as String?,
        paymentReference: json['paymentReference'] as String?,
        cardLast4: json['cardLast4'] as String?,
        appointmentId: json['appointmentId'] as int?,
        ambulanceRequestId: json['ambulanceRequestId'] as int?,
        serviceDate: ApiDates.parseLocal(json['serviceDate'])!,
        patient: InvoicePatient.fromJson(json['patient'] as Map<String, dynamic>),
        issuer: InvoiceIssuer.fromJson(json['issuer'] as Map<String, dynamic>),
        verifyUrl: json['verifyUrl'] as String?,
      );
}

/// Consultation (médecin) ou transport (société) terminé, pas encore facturé : un seul des deux identifiants.
class ToInvoice {
  const ToInvoice({
    this.appointmentId,
    this.ambulanceRequestId,
    required this.serviceDate,
    required this.patient,
    required this.suggestedAct,
    required this.suggestedFee,
    this.reason,
  });

  final int? appointmentId;
  final int? ambulanceRequestId;
  final DateTime serviceDate;
  final String? reason;
  final InvoicePatient patient;
  final String suggestedAct;
  final double suggestedFee;

  factory ToInvoice.fromJson(Map<String, dynamic> json) => ToInvoice(
        appointmentId: json['appointmentId'] as int?,
        ambulanceRequestId: json['ambulanceRequestId'] as int?,
        serviceDate: ApiDates.parseLocal(json['serviceDate'])!,
        reason: json['reason'] as String?,
        patient: InvoicePatient.fromJson(json['patient'] as Map<String, dynamic>),
        suggestedAct: json['suggestedAct'] as String,
        suggestedFee: (json['suggestedFee'] as num).toDouble(),
      );
}

class BillingSummary {
  const BillingSummary({
    required this.collectedToday,
    required this.collectedThisMonth,
    required this.unpaidCount,
    required this.unpaidAmount,
    required this.cnamReceivableThisMonth,
    required this.toInvoiceCount,
    required this.cnamRatePercent,
  });

  final double collectedToday;
  final double collectedThisMonth;
  final int unpaidCount;
  final double unpaidAmount;
  final double cnamReceivableThisMonth;
  final int toInvoiceCount;
  final int cnamRatePercent;

  factory BillingSummary.fromJson(Map<String, dynamic> json) => BillingSummary(
        collectedToday: (json['collectedToday'] as num).toDouble(),
        collectedThisMonth: (json['collectedThisMonth'] as num).toDouble(),
        unpaidCount: (json['unpaidCount'] as num).toInt(),
        unpaidAmount: (json['unpaidAmount'] as num).toDouble(),
        cnamReceivableThisMonth: (json['cnamReceivableThisMonth'] as num).toDouble(),
        toInvoiceCount: (json['toInvoiceCount'] as num).toInt(),
        cnamRatePercent: (json['cnamRatePercent'] as num).toInt(),
      );
}
