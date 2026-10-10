import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/location_helper.dart';
import '../../models/pharmacy.dart';
import '../../services/pharmacy_service.dart';
import '../../widgets/async_view.dart';
import '../../widgets/pharmacy_map.dart';
import '../../widgets/ui_helpers.dart';

/// Profil de l'officine : coordonnées, géolocalisation (utilisée par la recherche de proximité), garde.
class PharmacyProfileScreen extends StatelessWidget {
  const PharmacyProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AsyncView<Pharmacy>(
      load: context.read<PharmacyService>().getMine,
      builder: (context, pharmacy, _) => _PharmacyForm(pharmacy: pharmacy),
    );
  }
}

class _PharmacyForm extends StatefulWidget {
  const _PharmacyForm({required this.pharmacy});

  final Pharmacy pharmacy;

  @override
  State<_PharmacyForm> createState() => _PharmacyFormState();
}

class _PharmacyFormState extends State<_PharmacyForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.pharmacy.name);
  late final _address = TextEditingController(text: widget.pharmacy.address);
  late final _phone = TextEditingController(text: widget.pharmacy.phone ?? '');
  late final _hours = TextEditingController(text: widget.pharmacy.openingHours ?? '');
  late double _lat = widget.pharmacy.latitude;
  late double _lng = widget.pharmacy.longitude;
  late bool _onDuty = widget.pharmacy.onDuty;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _address, _phone, _hours]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _useMyLocation() async {
    final p = await LocationHelper.current();
    if (!mounted) return;
    if (p.isFallback) {
      showSnack(context, 'Localisation indisponible', isError: true);
      return;
    }
    setState(() {
      _lat = p.lat;
      _lng = p.lng;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await runWithFeedback(
      context,
      () => context.read<PharmacyService>().updateMine(
            name: _name.text.trim(),
            address: _address.text.trim(),
            phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
            latitude: _lat,
            longitude: _lng,
            openingHours: _hours.text.trim().isEmpty ? null : _hours.text.trim(),
            onDuty: _onDuty,
          ),
      successMessage: 'Officine mise à jour',
    );
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 14);
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nom de l\'officine'),
              validator: Validators.required),
          gap,
          TextFormField(
              controller: _address,
              decoration: const InputDecoration(labelText: 'Adresse'),
              validator: Validators.required),
          gap,
          TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Téléphone'),
              validator: Validators.phone),
          gap,
          TextFormField(
              controller: _hours,
              decoration: const InputDecoration(labelText: 'Horaires', hintText: 'Lun-Sam 08:00-20:00')),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Pharmacie de garde'),
            subtitle: const Text('Signalée en rouge sur la carte des patients'),
            value: _onDuty,
            onChanged: (v) => setState(() => _onDuty = v),
          ),
          const SizedBox(height: 8),
          Text('Position (${_lat.toStringAsFixed(5)}, ${_lng.toStringAsFixed(5)})'),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 180,
              child: PharmacyMap(
                key: ValueKey('$_lat,$_lng'),
                userLat: _lat,
                userLng: _lng,
                zoom: 15,
                pharmacies: const [],
              ),
            ),
          ),
          TextButton.icon(
            onPressed: _useMyLocation,
            icon: const Icon(Icons.my_location),
            label: const Text('Utiliser ma position actuelle'),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _saving ? null : _save, child: const Text('Enregistrer')),
        ],
      ),
    );
  }
}
