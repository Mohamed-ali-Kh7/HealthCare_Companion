import 'package:flutter/material.dart';

import '../core/utils/formatters.dart';
import '../models/order.dart';
import 'status_chip.dart';

/// Carte d'une réservation / commande. [forPharmacist] : affiche le patient au lieu de la pharmacie.
class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order, this.forPharmacist = false, this.actions = const []});

  final MedicineOrder order;
  final bool forPharmacist;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(o.type.icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(o.type.label, style: theme.textTheme.labelLarge)),
                StatusChip(label: o.statusLabel, color: o.status.color),
              ],
            ),
            const SizedBox(height: 10),
            Text('${o.quantity} × ${o.medicine.name} ${o.medicine.strength}', style: theme.textTheme.titleMedium),
            Text(o.medicine.formLabel, style: muted),
            const SizedBox(height: 8),
            if (forPharmacist) ...[
              _line(Icons.person, o.patient.fullName),
              if (o.phone != null) _line(Icons.phone, o.phone!),
            ] else ...[
              _line(Icons.local_pharmacy, o.pharmacy.name),
              _line(Icons.place, o.pharmacy.address),
            ],
            if (o.isDelivery && o.deliveryAddress != null)
              _line(Icons.local_shipping, 'Livraison : ${o.deliveryAddress}'),
            _line(
                Icons.payments_outlined,
                o.totalPrice == null
                    ? 'Prix communiqué par la pharmacie'
                    : '${Fmt.price(o.totalPrice)} · ${o.isDelivery ? 'paiement à la livraison' : 'paiement sur place'}'),
            _line(Icons.schedule, 'Le ${Fmt.dateTime(o.createdAt)}'),
            if (o.note != null) _line(Icons.notes, 'Note : ${o.note}'),
            if (o.pharmacistNote != null)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: o.status.color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 16, color: o.status.color),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Pharmacie : ${o.pharmacistNote}')),
                  ],
                ),
              ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 4, children: actions),
            ],
          ],
        ),
      ),
    );
  }

  Widget _line(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(child: Text(text)),
          ],
        ),
      );
}
