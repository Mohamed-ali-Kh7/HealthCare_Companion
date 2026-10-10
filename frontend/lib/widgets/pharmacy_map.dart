import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/pharmacy.dart';

/// Carte OpenStreetMap : position de l'utilisateur + pharmacies.
class PharmacyMap extends StatelessWidget {
  const PharmacyMap({
    super.key,
    required this.userLat,
    required this.userLng,
    required this.pharmacies,
    this.onPharmacyTap,
    this.zoom = 13,
  });

  final double userLat;
  final double userLng;
  final List<Pharmacy> pharmacies;
  final ValueChanged<Pharmacy>? onPharmacyTap;
  final double zoom;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FlutterMap(
      options: MapOptions(initialCenter: LatLng(userLat, userLng), initialZoom: zoom),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.healthcare.healthcare_companion',
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: LatLng(userLat, userLng),
              width: 36,
              height: 36,
              child: Icon(Icons.my_location, color: scheme.primary, size: 28),
            ),
            for (final p in pharmacies)
              Marker(
                point: LatLng(p.latitude, p.longitude),
                width: 44,
                height: 44,
                child: GestureDetector(
                  onTap: onPharmacyTap == null ? null : () => onPharmacyTap!(p),
                  child: Tooltip(
                    message: p.name,
                    child: Icon(Icons.local_pharmacy,
                        size: 36, color: p.onDuty ? Colors.red.shade700 : Colors.green.shade700),
                  ),
                ),
              ),
          ],
        ),
        const RichAttributionWidget(
          attributions: [TextSourceAttribution('© contributeurs OpenStreetMap')],
        ),
      ],
    );
  }
}
