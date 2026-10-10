import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/utils/formatters.dart';
import '../models/pharmacy.dart';
import '../services/pharmacy_service.dart';
import 'async_view.dart';
import 'status_chip.dart';

/// Fiche pharmacie : coordonnées + médicaments disponibles.
Future<void> showPharmacySheet(BuildContext context, Pharmacy pharmacy) {
  final service = context.read<PharmacyService>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      builder: (context, controller) => AsyncView<List<StockItem>>(
        load: () => service.getPharmacyStock(pharmacy.id),
        builder: (context, stock, _) => ListView(
          controller: controller,
          children: [
            ListTile(
              title: Text(pharmacy.name, style: Theme.of(context).textTheme.titleLarge),
              subtitle: Text(pharmacy.address),
              trailing: pharmacy.onDuty
                  ? const StatusChip(label: 'De garde', color: Colors.red)
                  : null,
            ),
            if (pharmacy.phone != null)
              ListTile(leading: const Icon(Icons.phone), title: Text(pharmacy.phone!)),
            if (pharmacy.openingHours != null)
              ListTile(leading: const Icon(Icons.schedule), title: Text(pharmacy.openingHours!)),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text('Disponible en stock (${stock.length})',
                  style: Theme.of(context).textTheme.titleSmall),
            ),
            for (final s in stock)
              ListTile(
                dense: true,
                title: Text('${s.medicine.name} ${s.medicine.strength}'),
                subtitle: Text(s.medicine.formLabel),
                trailing: Text(Fmt.price(s.price)),
              ),
          ],
        ),
      ),
    ),
  );
}
