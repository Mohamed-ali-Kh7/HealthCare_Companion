import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:healthcare_companion/core/pdf/invoice_pdf.dart';
import 'package:healthcare_companion/models/invoice.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('fr_FR'));

  Map<String, dynamic> json({String status = 'UNPAID', String coverage = 'REIMBURSEMENT'}) => {
        'id': 7,
        'number': 'F-2026-000007',
        'issuedAt': '2026-11-15T10:00:00Z',
        'act': 'CONSULTATION',
        'actLabel': 'Consultation de médecine générale',
        'amount': 45.0,
        'coverage': coverage,
        'coverageLabel': 'Système de remboursement',
        'cnamNumber': '12345678 / 00',
        'cnamRatePercent': 70,
        'cnamShare': 31.5,
        'patientDue': 45.0,
        'status': status,
        'paidAt': status == 'PAID' ? '2026-11-15T11:00:00Z' : null,
        'paymentMethod': status == 'PAID' ? 'CARD' : null,
        'paymentReference': status == 'PAID' ? 'SIM-ABC' : null,
        'cardLast4': status == 'PAID' ? '4242' : null,
        'appointmentId': 3,
        'ambulanceRequestId': null,
        'serviceDate': '2026-11-14T09:00:00',
        'patient': {
          'id': 1,
          'firstName': 'Amira',
          'lastName': 'Ben Salah',
          'dateOfBirth': '1995-04-12',
          'cnamNumber': '12345678 / 00',
        },
        'issuer': {
          'kind': 'DOCTOR',
          'id': 1,
          'name': 'Dr Karim Trabelsi',
          'subtitle': 'Médecine générale',
          'address': '12 avenue Habib Bourguiba, Tunis',
          'phone': '+216 71 000 002',
        },
        'verifyUrl': 'http://localhost:8081/verify/invoice/7-abc',
      };

  test('lit la facture renvoyée par le serveur', () {
    final i = Invoice.fromJson(json(status: 'PAID'));
    expect(i.isPaid, isTrue);
    expect(i.coverage, CnamCoverage.reimbursement);
    expect(i.expectsRefund, isTrue);
    expect(i.paymentLabel, 'Carte bancaire •••• 4242');
    expect(i.issuer.name, 'Dr Karim Trabelsi');
    expect(i.isTransport, isFalse);
  });

  test('génère la facture et le bulletin de soins en PDF', () async {
    for (final status in ['PAID', 'UNPAID']) {
      final invoice = Invoice.fromJson(json(status: status));
      final facture = await InvoicePdf.buildInvoice(invoice);
      final bulletin = await InvoicePdf.buildBulletin(invoice);
      expect(String.fromCharCodes(facture.take(5)), '%PDF-');
      expect(String.fromCharCodes(bulletin.take(5)), '%PDF-');
    }
    expect(InvoicePdf.invoiceFileName(Invoice.fromJson(json())), 'facture-F-2026-000007.pdf');
  });
}
