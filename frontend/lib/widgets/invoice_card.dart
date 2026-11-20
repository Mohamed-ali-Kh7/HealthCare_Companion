import 'package:flutter/material.dart';

import '../core/pdf/invoice_pdf.dart';
import '../core/utils/formatters.dart';
import '../models/invoice.dart';
import 'status_chip.dart';
import 'ui_helpers.dart';

/// Facture (vue patient ou médecin) : montants, prise en charge CNAM, statut, PDF.
class InvoiceCard extends StatelessWidget {
  const InvoiceCard({super.key, required this.invoice, required this.forDoctor, this.actions = const []});

  final Invoice invoice;
  final bool forDoctor;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final i = invoice;
    final scheme = Theme.of(context).colorScheme;
    final muted = TextStyle(color: scheme.onSurfaceVariant);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(forDoctor ? i.patient.fullName : i.issuer.name,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                StatusChip(label: i.status.label, color: i.status.color),
              ],
            ),
            Text('${i.actLabel} · ${Fmt.date(i.serviceDate)}', style: muted),
            Text('Facture ${i.number}', style: muted.copyWith(fontSize: 12)),
            const Divider(height: 20),
            _row('Honoraires', Fmt.price(i.amount)),
            _row(i.coverage.label,
                i.coverage == CnamCoverage.none ? '—' : 'CNAM ${i.cnamRatePercent} % : ${Fmt.price(i.cnamShare)}'),
            _row(forDoctor ? 'Dû par le patient' : 'À payer', Fmt.price(i.patientDue), bold: true),
            if (i.expectsRefund && !forDoctor)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('↩ Remboursement CNAM attendu : ${Fmt.price(i.cnamShare)} (déposez le bulletin de soins)',
                    style: TextStyle(color: scheme.primary, fontSize: 12.5)),
              ),
            if (i.isPaid)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Réglée le ${Fmt.date(i.paidAt)} · ${i.paymentLabel}', style: muted.copyWith(fontSize: 12.5)),
              ),
            const SizedBox(height: 4),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 4,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: const Text('Facture'),
                  onPressed: () => runWithFeedback(context, () => InvoicePdf.shareInvoice(i)),
                ),
                if (i.coverage != CnamCoverage.none)
                  TextButton.icon(
                    icon: const Icon(Icons.description_outlined, size: 18),
                    label: const Text('Bulletin CNAM'),
                    onPressed: () => runWithFeedback(context, () => InvoicePdf.shareBulletin(i)),
                  ),
                ...actions,
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    final style = TextStyle(fontWeight: bold ? FontWeight.w700 : null);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [Expanded(child: Text(label, style: style)), Text(value, style: style)]),
    );
  }
}
