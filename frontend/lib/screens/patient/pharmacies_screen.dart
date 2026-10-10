import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/location_helper.dart';
import '../../models/pharmacy.dart';
import '../../services/pharmacy_service.dart';
import '../../widgets/async_view.dart';
import '../../widgets/medicine_picker.dart';
import '../../widgets/pharmacy_map.dart';
import '../../widgets/pharmacy_sheet.dart';
import 'medicine_availability_screen.dart';

/// Pharmacies proches (carte + liste) et accès à la recherche de disponibilité d'un médicament.
class PharmaciesScreen extends StatefulWidget {
  const PharmaciesScreen({super.key});

  @override
  State<PharmaciesScreen> createState() => _PharmaciesScreenState();
}

class _PharmaciesScreenState extends State<PharmaciesScreen> {
  static const _radii = [2.0, 5.0, 10.0, 20.0];
  double _radius = 5;
  Key _viewKey = UniqueKey();

  Future<(GeoPoint, List<Pharmacy>)> _load() async {
    final service = context.read<PharmacyService>();
    final position = await LocationHelper.current();
    final pharmacies = await service.findNearby(position.lat, position.lng, radiusKm: _radius);
    return (position, pharmacies);
  }

  Future<void> _searchMedicine() async {
    final medicine = await pickMedicine(context);
    if (medicine == null || !mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MedicineAvailabilityScreen(medicine: medicine)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _searchMedicine,
        icon: const Icon(Icons.medication),
        label: const Text('Trouver un médicament'),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                for (final r in _radii)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text('${r.toInt()} km'),
                      selected: _radius == r,
                      onSelected: (_) => setState(() {
                        _radius = r;
                        _viewKey = UniqueKey();
                      }),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: AsyncView<(GeoPoint, List<Pharmacy>)>(
              key: _viewKey,
              load: _load,
              builder: (context, data, reload) {
                final (position, pharmacies) = data;
                return Column(
                  children: [
                    if (position.isFallback)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        child: const Text('Localisation indisponible : résultats autour du centre de Tunis.'),
                      ),
                    SizedBox(
                      height: 240,
                      child: PharmacyMap(
                        userLat: position.lat,
                        userLng: position.lng,
                        pharmacies: pharmacies,
                        onPharmacyTap: (p) => showPharmacySheet(context, p),
                      ),
                    ),
                    Expanded(
                      child: RefreshableList(
                        onRefresh: reload,
                        itemCount: pharmacies.length,
                        empty: EmptyState(
                          icon: Icons.local_pharmacy_outlined,
                          message: 'Aucune pharmacie dans un rayon de ${_radius.toInt()} km',
                        ),
                        itemBuilder: (context, i) {
                          final p = pharmacies[i];
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.local_pharmacy),
                              title: Text(p.name),
                              subtitle: Text(p.address, maxLines: 1, overflow: TextOverflow.ellipsis),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(p.distanceLabel,
                                      style: const TextStyle(fontWeight: FontWeight.bold)),
                                  if (p.onDuty) const Text('De garde', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                              onTap: () => showPharmacySheet(context, p),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
