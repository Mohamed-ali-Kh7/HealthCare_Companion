import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/location_helper.dart';
import '../../models/transport.dart';
import '../../services/transport_service.dart';
import '../../widgets/async_view.dart';
import '../../widgets/ui_helpers.dart';

/// Profil de la société : coordonnées, position et rayon d'intervention (recherche des patients),
/// acceptation des nouvelles demandes.
class CompanyProfileScreen extends StatelessWidget {
  const CompanyProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AsyncView<AmbulanceCompany>(
      load: context.read<TransportService>().getMyCompany,
      builder: (context, company, _) => _CompanyForm(company: company),
    );
  }
}

class _CompanyForm extends StatefulWidget {
  const _CompanyForm({required this.company});

  final AmbulanceCompany company;

  @override
  State<_CompanyForm> createState() => _CompanyFormState();
}

class _CompanyFormState extends State<_CompanyForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.company.name);
  late final _address = TextEditingController(text: widget.company.address);
  late final _city = TextEditingController(text: widget.company.city);
  late final _phone = TextEditingController(text: widget.company.phone);
  late double _lat = widget.company.latitude;
  late double _lng = widget.company.longitude;
  late double _radius = widget.company.serviceRadiusKm.toDouble();
  late bool _accepting = widget.company.acceptingRequests;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _address, _city, _phone]) {
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
      () => context.read<TransportService>().updateMyCompany(
            name: _name.text.trim(),
            address: _address.text.trim(),
            city: _city.text.trim(),
            phone: _phone.text.trim(),
            latitude: _lat,
            longitude: _lng,
            serviceRadiusKm: _radius.round(),
            acceptingRequests: _accepting,
          ),
      successMessage: 'Profil enregistré',
    );
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 14);
    final c = widget.company;
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.verified_outlined),
              title: Text('Convention CNAM ${c.conventionNumber}'),
              subtitle: Text('${c.vehiclesInService ?? 0} véhicule(s) en service'),
            ),
          ),
          gap,
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _accepting,
            onChanged: (v) => setState(() => _accepting = v),
            title: const Text('J\'accepte de nouvelles demandes'),
            subtitle: const Text('Désactivé : la société n\'apparaît plus dans la recherche des patients'),
          ),
          gap,
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nom de la société'),
            validator: Validators.required,
          ),
          gap,
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Téléphone (joignable 24 h/24)'),
            validator: (v) => v == null || v.trim().isEmpty ? 'Obligatoire' : Validators.phone(v),
          ),
          gap,
          TextFormField(
            controller: _address,
            decoration: const InputDecoration(labelText: 'Adresse'),
            validator: Validators.required,
          ),
          gap,
          TextFormField(
            controller: _city,
            decoration: const InputDecoration(labelText: 'Ville'),
            validator: Validators.required,
          ),
          gap,
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.place_outlined),
            title: const Text('Position de la base'),
            subtitle: Text('${_lat.toStringAsFixed(5)}, ${_lng.toStringAsFixed(5)}'),
            trailing: TextButton.icon(
              onPressed: _useMyLocation,
              icon: const Icon(Icons.my_location),
              label: const Text('Ma position'),
            ),
          ),
          Text('Rayon d\'intervention : ${_radius.round()} km'),
          Slider(
            value: _radius,
            min: 5,
            max: 150,
            divisions: 29,
            label: '${_radius.round()} km',
            onChanged: (v) => setState(() => _radius = v),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _saving ? null : _save, child: const Text('Enregistrer')),
        ],
      ),
    );
  }
}
