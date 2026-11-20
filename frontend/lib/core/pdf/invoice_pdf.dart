import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/invoice.dart';
import '../utils/formatters.dart';

/// Facture et bulletin de soins CNAM (pré-rempli) au format PDF, générés sur l'appareil.
/// La prise en charge CNAM est simulée : le bulletin est un modèle à présenter, pas le formulaire officiel.
class InvoicePdf {
  InvoicePdf._();

  static const _primary = PdfColor.fromInt(0xFF00796B);
  static const _muted = PdfColor.fromInt(0xFF666666);

  static String invoiceFileName(Invoice i) => 'facture-${i.number}.pdf';

  static String bulletinFileName(Invoice i) => 'bulletin-de-soins-${i.number}.pdf';

  static Future<void> shareInvoice(Invoice i) async =>
      Printing.sharePdf(bytes: await buildInvoice(i), filename: invoiceFileName(i));

  static Future<void> shareBulletin(Invoice i) async =>
      Printing.sharePdf(bytes: await buildBulletin(i), filename: bulletinFileName(i));

  // ---------------------------------------------------------------- Facture

  static Future<Uint8List> buildInvoice(Invoice i) async {
    final doc = pw.Document(title: 'Facture ${i.number}', author: i.issuer.name, creator: 'HealthCare Companion');
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 36),
      theme: await _theme(),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _header(i),
          pw.SizedBox(height: 18),
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Expanded(
              child: pw.Text('FACTURE',
                  style: const pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, letterSpacing: 3, color: _primary)),
            ),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('N° ${i.number}', style: const pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('Émise le ${Fmt.dateLong(i.issuedAt)}', style: const pw.TextStyle(color: _muted, fontSize: 10)),
            ]),
          ]),
          pw.SizedBox(height: 16),
          _box('Patient', [
            i.patient.fullName,
            if (i.patient.dateOfBirth != null) 'Né(e) le ${Fmt.date(i.patient.dateOfBirth)}',
            if (i.cnamNumber != null) 'N° CNAM : ${i.cnamNumber}',
          ]),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headerStyle: const pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: _primary),
            cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.centerLeft, 2: pw.Alignment.centerRight},
            headers: ['Date', 'Acte', 'Montant'],
            data: [
              [Fmt.date(i.serviceDate), i.actLabel, Fmt.price(i.amount)],
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.SizedBox(
              width: 280,
              child: pw.Column(children: [
                _line('Total', Fmt.price(i.amount), bold: true),
                _line('Prise en charge', i.coverage.label),
                if (i.coverage != CnamCoverage.none)
                  _line('Part CNAM (${i.cnamRatePercent} %)', Fmt.price(i.cnamShare)),
                pw.Divider(color: PdfColors.grey400),
                _line('À régler par le patient', Fmt.price(i.patientDue), bold: true),
                if (i.expectsRefund)
                  _line('Remboursement CNAM attendu', Fmt.price(i.cnamShare)),
              ]),
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: i.isPaid ? const PdfColor.fromInt(0xFFE3F4EC) : const PdfColor.fromInt(0xFFFFF3E0),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Text(
              i.isPaid
                  ? 'ACQUITTÉE le ${Fmt.date(i.paidAt)} · ${i.paymentLabel}'
                      '${i.paymentReference == null ? '' : ' · Réf. ${i.paymentReference}'}'
                  : 'NON RÉGLÉE : montant dû ${Fmt.price(i.patientDue)}',
              style: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Spacer(),
          pw.Text(
            'Paiement en ligne et prise en charge CNAM simulés (projet académique). '
            'Scannez le QR code pour vérifier l\'authenticité de cette facture.',
            style: const pw.TextStyle(fontSize: 8, color: _muted),
          ),
        ],
      ),
    ));
    return doc.save();
  }

  // ---------------------------------------------------------------- Bulletin de soins

  static Future<Uint8List> buildBulletin(Invoice i) async {
    final doc = pw.Document(title: 'Bulletin de soins ${i.number}', creator: 'HealthCare Companion');
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 36),
      theme: await _theme(),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Expanded(
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('BULLETIN DE SOINS',
                    style: const pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: _primary)),
                pw.Text('Assurance maladie (CNAM) · modèle pré-rempli',
                    style: const pw.TextStyle(fontSize: 10, color: _muted)),
              ]),
            ),
            _qr(i),
          ]),
          pw.SizedBox(height: 16),
          _section('1. Assuré social', [
            ('Nom et prénom', i.patient.fullName),
            ('Date de naissance', Fmt.date(i.patient.dateOfBirth)),
            ('Identifiant CNAM', i.cnamNumber ?? '—'),
            ('Filière', i.coverage.label),
          ]),
          _section(i.issuer.isAmbulance ? '2. Transporteur sanitaire' : '2. Professionnel de santé', [
            (i.issuer.isAmbulance ? "Société d'ambulance" : 'Médecin', i.issuer.name),
            (i.issuer.isAmbulance ? 'Convention' : 'Spécialité', i.issuer.subtitle),
            ('Adresse', i.issuer.address ?? '—'),
            ('Téléphone', i.issuer.phone ?? '—'),
          ]),
          _section('3. Actes', [
            (i.isTransport ? 'Date du transport' : 'Date des soins', Fmt.date(i.serviceDate)),
            ('Acte', i.actLabel),
            ('Honoraires', Fmt.price(i.amount)),
            ('Montant payé par l\'assuré', Fmt.price(i.patientDue)),
            ('Part CNAM (${i.cnamRatePercent} %)', Fmt.price(i.cnamShare)),
            ('Facture', '${i.number}${i.isPaid ? ' (acquittée le ${Fmt.date(i.paidAt)})' : ' (non réglée)'}'),
          ]),
          pw.SizedBox(height: 24),
          pw.Row(children: [
            pw.Expanded(child: _signature('Signature de l\'assuré')),
            pw.SizedBox(width: 24),
            pw.Expanded(child: _signature(i.issuer.isAmbulance ? 'Cachet de la société' : 'Cachet et signature du médecin')),
          ]),
          pw.Spacer(),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(4)),
            child: pw.Text(
              'Document pré-rempli par HealthCare Companion (projet académique). La prise en charge CNAM est simulée : '
              'pour un remboursement réel, utilisez le bulletin de soins officiel de la CNAM.',
              style: const pw.TextStyle(fontSize: 8.5, color: _muted),
            ),
          ),
        ],
      ),
    ));
    return doc.save();
  }

  // ---------------------------------------------------------------- Éléments communs

  static pw.Widget _header(Invoice i) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 10),
        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _primary, width: 2))),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(i.issuer.name,
                  style: const pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: _primary)),
              pw.Text(i.issuer.subtitle, style: const pw.TextStyle(fontSize: 11)),
              if (i.issuer.address != null) pw.Text(i.issuer.address!, style: const pw.TextStyle(fontSize: 9.5, color: _muted)),
              if (i.issuer.phone != null) pw.Text('Tél. ${i.issuer.phone}', style: const pw.TextStyle(fontSize: 9.5, color: _muted)),
            ]),
          ),
          _qr(i),
        ]),
      );

  static pw.Widget _qr(Invoice i) => pw.Column(children: [
        pw.BarcodeWidget(
          barcode: pw.Barcode.qrCode(),
          data: i.verifyUrl ?? 'HCC-FACT-${i.number}',
          width: 64,
          height: 64,
          drawText: false,
        ),
        pw.SizedBox(height: 3),
        pw.Text(i.verifyUrl == null ? i.number : 'Scanner pour vérifier',
            style: const pw.TextStyle(fontSize: 7, color: _muted)),
      ]);

  static pw.Widget _box(String title, List<String> lines) => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(4)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(title, style: const pw.TextStyle(fontSize: 9, color: _muted)),
          for (var k = 0; k < lines.length; k++)
            pw.Text(lines[k], style: pw.TextStyle(fontSize: k == 0 ? 12.5 : 10.5, fontWeight: k == 0 ? pw.FontWeight.bold : null)),
        ]),
      );

  static pw.Widget _line(String label, String value, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(children: [
          pw.Expanded(child: pw.Text(label, style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : null))),
          pw.Text(value, style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : null)),
        ]),
      );

  static pw.Widget _section(String title, List<(String, String)> rows) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 12),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          pw.Container(
            color: const PdfColor.fromInt(0xFFE0F2F1),
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: pw.Text(title, style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, color: _primary)),
          ),
          for (final r in rows)
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfColors.grey200))),
              child: pw.Row(children: [
                pw.SizedBox(width: 170, child: pw.Text(r.$1, style: const pw.TextStyle(fontSize: 10, color: _muted))),
                pw.Expanded(child: pw.Text(r.$2, style: const pw.TextStyle(fontSize: 10.5))),
              ]),
            ),
        ]),
      );

  static pw.Widget _signature(String label) => pw.Column(children: [
        pw.SizedBox(height: 50),
        pw.Divider(color: PdfColors.grey500),
        pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: _muted)),
      ]);

  static Future<pw.ThemeData> _theme() async {
    try {
      return pw.ThemeData.withFont(
        base: await PdfGoogleFonts.notoSansRegular(),
        bold: await PdfGoogleFonts.notoSansBold(),
        italic: await PdfGoogleFonts.notoSansItalic(),
      );
    } catch (e) {
      debugPrint('Police PDF indisponible, Helvetica utilisée : $e');
      return pw.ThemeData.base();
    }
  }
}
