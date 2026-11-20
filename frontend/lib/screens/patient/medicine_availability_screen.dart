import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../core/utils/location_helper.dart';
import '../../models/medicine.dart';
import '../../models/order.dart';
import '../../models/pharmacy.dart';
import '../../services/pharmacy_service.dart';
import '../../widgets/async_view.dart';
import '../../widgets/pharmacy_map.dart';
import '../../widgets/pharmacy_sheet.dart';
import 'my_orders_screen.dart';
import 'order_form_screen.dart';

/// "Où trouver ce médicament près de moi ?" : pharmacies proches qui l'ont en stock.
class MedicineAvailabilityScreen extends StatelessWidget {
  const MedicineAvailabilityScreen({super.key, required this.medicine});

  final Medicine medicine;

  Future<void> _order(
      BuildContext context, MedicineAvailability availability, OrderType type, Future<void> Function() reload) async {
    final sent = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => OrderFormScreen(medicine: medicine, availability: availability, initialType: type),
    ));
    if (sent == true && context.mounted) {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyOrdersScreen()));
      await reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<PharmacyService>();
    return Scaffold(
      appBar: AppBar(
        title: Text('${medicine.name} ${medicine.strength}'),
        actions: [
          IconButton(
            tooltip: 'Mes commandes',
            icon: const Icon(Icons.shopping_bag_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyOrdersScreen())),
          ),
        ],
      ),
      body: AsyncView<(GeoPoint, List<MedicineAvailability>)>(
        load: () async {
          final position = await LocationHelper.current();
          final results = await service.findAvailability(medicine.id, position.lat, position.lng);
          return (position, results);
        },
        builder: (context, data, reload) {
          final (position, results) = data;
          return Column(
            children: [
              SizedBox(
                height: 220,
                child: PharmacyMap(
                  userLat: position.lat,
                  userLng: position.lng,
                  zoom: 12,
                  pharmacies: results.map((r) => r.pharmacy).toList(),
                  onPharmacyTap: (p) => showPharmacySheet(context, p),
                ),
              ),
              Expanded(
                child: RefreshableList(
                  onRefresh: reload,
                  itemCount: results.length,
                  empty: const EmptyState(
                    icon: Icons.inventory_2_outlined,
                    message: 'Aucune pharmacie à moins de 10 km n\'a ce médicament en stock.',
                  ),
                  itemBuilder: (context, i) {
                    final r = results[i];
                    return Card(
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.check_circle, color: Colors.green),
                            title: Text(r.pharmacy.name),
                            subtitle: Text('${r.pharmacy.address}\n${r.quantity} en stock · ${Fmt.price(r.price)}'),
                            isThreeLine: true,
                            trailing:
                                Text(r.pharmacy.distanceLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                            onTap: () => showPharmacySheet(context, r.pharmacy),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _order(context, r, OrderType.reservation, reload),
                                    icon: const Icon(Icons.storefront),
                                    label: const Text('Réserver'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () => _order(context, r, OrderType.delivery, reload),
                                    icon: const Icon(Icons.local_shipping),
                                    label: const Text('Commander'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
