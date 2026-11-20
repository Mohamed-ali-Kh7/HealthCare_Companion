
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/prescription.dart';
import '../utils/formatters.dart';

/// Ordonnance au format PDF (A4) : téléchargement / partage ou impression.
/// Généré sur l'appareil à partir des données déjà chargées : aucun appel serveur supplémentaire.
class PrescriptionPdf {
  PrescriptionPdf._();

  static const _primary = PdfColor.fromInt(0xFF00796B);
  static const _muted = PdfColor.fromInt(0xFF666666);

  /// Nom du fichier : ordonnance-12-2026-11-13.pdf
  static String fileName(Prescription p) =>
      'ordonnance-${p.id}-${p.date.year}-${_two(p.date.month)}-${_two(p.date.day)}.pdf';

  /// Web : téléchargement du fichier. Mobile : feuille de partage (enregistrer, envoyer...).
  static Future<void> share(Prescription p) async =>
      Printing.sharePdf(bytes: await build(p), filename: fileName(p));

  /// Aperçu avant impression (ou « Enregistrer en PDF » selon l'appareil).
  static Future<void> printDocument(Prescription p) async =>
      Printing.layoutPdf(name: fileName(p), onLayout: (_) => build(p));

  static Future<Uint8List> build(Prescription p) async {
    final theme = await _theme();
    final doc = pw.Document(
      title: 'Ordonnance n° ${p.id}',
      author: p.doctorName,
      creator: 'HealthCare Companion',
    );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 36),
      theme: theme,
      header: (context) => _header(p),
      footer: (context) => _footer(p, context),
      build: (context) => [
        pw.SizedBox(height: 18),
        pw.Center(
          child: pw.Text('ORDONNANCE',
              style: const pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, letterSpacing: 3, color: _primary)),
        ),
        pw.SizedBox(height: 18),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('Patient', style: const pw.TextStyle(color: _muted, fontSize: 10)),
                pw.Text(p.patient.fullName, style: const pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
              ]),
            ),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('Date', style: const pw.TextStyle(color: _muted, fontSize: 10)),
              pw.Text(Fmt.dateLong(p.date), style: const pw.TextStyle(fontSize: 13)),
            ]),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Divider(color: PdfColors.grey400),
        pw.SizedBox(height: 8),
        for (var i = 0; i < p.items.length; i++) _item(i + 1, p.items[i]),
        if (p.notes != null && p.notes!.trim().isNotEmpty) ...[
          pw.SizedBox(height: 12),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text('Remarques : ${p.notes}', style: const pw.TextStyle(fontSize: 11)),
          ),
        ],
        pw.SizedBox(height: 40),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Container(
            width: 200,
            child: pw.Column(children: [
              pw.Text(p.doctorName, style: const pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 50),
              pw.Divider(color: PdfColors.grey500),
              pw.Text('Signature et cachet', style: const pw.TextStyle(color: _muted, fontSize: 9)),
            ]),
          ),
        ),
      ],
    ));
    return doc.save();
  }

  static pw.Widget _header(Prescription p) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 10),
        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _primary, width: 2))),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(p.doctorName,
                    style: const pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: _primary)),
                pw.Text(p.doctorSpeciality, style: const pw.TextStyle(fontSize: 11)),
              ]),
            ),
            // Scanné avec un téléphone : ouvre la page « ordonnance authentique » du serveur
            pw.Column(children: [
              pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: p.verificationUrl ?? 'HCC-ORD-${p.id}',
                width: 64,
                height: 64,
                drawText: false,
              ),
              pw.SizedBox(height: 3),
              pw.Text(p.verificationUrl == null ? 'Réf. ${p.id}' : 'Scanner pour vérifier',
                  style: const pw.TextStyle(fontSize: 7, color: _muted)),
            ]),
          ],
        ),
      );

  static pw.Widget _item(int index, PrescriptionItem item) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 12),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 22,
              child: pw.Text('$index.', style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, color: _primary)),
            ),
            pw.Expanded(
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('${item.medicine.name} ${item.medicine.strength} (${item.medicine.formLabel})',
                    style: const pw.TextStyle(fontSize: 12.5, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                pw.Text(item.posology, style: const pw.TextStyle(fontSize: 11)),
                if (item.instructions != null && item.instructions!.trim().isNotEmpty)
                  pw.Text(item.instructions!, style: const pw.TextStyle(fontSize: 10.5, fontStyle: pw.FontStyle.italic)),
              ]),
            ),
          ],
        ),
      );

  static pw.Widget _footer(Prescription p, pw.Context context) => pw.Container(
        padding: const pw.EdgeInsets.only(top: 6),
        decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300))),
        child: pw.Row(children: [
          pw.Text('Ordonnance n° ${p.id} · HealthCare Companion',
              style: const pw.TextStyle(fontSize: 8, color: _muted)),
          pw.Spacer(),
          pw.Text('Page ${context.pageNumber}/${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: _muted)),
        ]),
      );

  /// Police avec accents complets (téléchargée puis mise en cache) ; Helvetica si hors ligne.
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

  static String _two(int v) => v.toString().padLeft(2, '0');
}
