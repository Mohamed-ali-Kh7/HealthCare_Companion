import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/transport.dart';
import '../../services/transport_service.dart';
import '../../widgets/async_view.dart';
import '../../widgets/ui_helpers.dart';

/// Société : véhicules (ambulances, VSL), équipage habituel, mise en / hors service.
class FleetScreen extends StatelessWidget {
  const FleetScreen({super.key});

  Future<void> _edit(BuildContext context, Future<void> Function() reload, [AmbulanceVehicle? vehicle]) async {
    final saved = await showModalBottomSheet<AmbulanceVehicle>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _VehicleSheet(vehicle: vehicle),
    );
    if (saved != null) await reload();
  }

  @override
  Widget build(BuildContext context) {
    return AsyncView<List<AmbulanceVehicle>>(
      load: () => context.read<TransportService>().getVehicles(),
      builder: (context, vehicles, reload) => Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.add),
          label: const Text('Véhicule'),
          onPressed: () => _edit(context, reload),
        ),
        body: RefreshableList(
          onRefresh: reload,
          itemCount: vehicles.length,
          empty: const EmptyState(
            icon: Icons.airport_shuttle_outlined,
            message: 'Aucun véhicule.\nAjoutez vos ambulances et VSL pour accepter des missions.',
          ),
          itemBuilder: (context, i) {
            final v = vehicles[i];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: ListTile(
                leading: CircleAvatar(
                  child: Icon(v.type == VehicleType.ambulance ? Icons.airport_shuttle : Icons.directions_car),
                ),
                title: Text(v.plate),
                subtitle: Text('${v.type.label}\n${v.driverName ?? 'Équipage non renseigné'}'
                    '${v.driverPhone == null ? '' : ' · ${v.driverPhone}'}'),
                isThreeLine: true,
                onTap: () => _edit(context, reload, v),
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: v.inService,
                      onChanged: (on) async {
                        final ok = await runWithFeedback(
                            context, () => context.read<TransportService>().setInService(v.id, on),
                            successMessage: on ? '${v.plate} en service' : '${v.plate} hors service');
                        if (ok) await reload();
                      },
                    ),
                    Text(v.inService ? 'En service' : 'Hors service', style: const TextStyle(fontSize: 11)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _VehicleSheet extends StatefulWidget {
  const _VehicleSheet({this.vehicle});

  final AmbulanceVehicle? vehicle;

  @override
  State<_VehicleSheet> createState() => _VehicleSheetState();
}

class _VehicleSheetState extends State<_VehicleSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _plate = TextEditingController(text: widget.vehicle?.plate ?? '');
  late final _driver = TextEditingController(text: widget.vehicle?.driverName ?? '');
  late final _driverPhone = TextEditingController(text: widget.vehicle?.driverPhone ?? '');
  late VehicleType _type = widget.vehicle?.type ?? VehicleType.ambulance;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_plate, _driver, _driverPhone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final saved = await context.read<TransportService>().saveVehicle(
            id: widget.vehicle?.id,
            plate: _plate.text.trim(),
            type: _type,
            driverName: _driver.text.trim().isEmpty ? null : _driver.text.trim(),
            driverPhone: _driverPhone.text.trim().isEmpty ? null : _driverPhone.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(saved);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showSnack(context, errorMessage(e), isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 12);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(widget.vehicle == null ? 'Nouveau véhicule' : 'Modifier le véhicule',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextFormField(
              controller: _plate,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Immatriculation', hintText: 'ex : 215 TU 3344'),
              validator: (v) => v == null || v.trim().isEmpty ? 'Obligatoire' : null,
            ),
            gap,
            SegmentedButton<VehicleType>(
              segments: const [
                ButtonSegment(value: VehicleType.ambulance, label: Text('Ambulance'), icon: Icon(Icons.airport_shuttle)),
                ButtonSegment(value: VehicleType.vsl, label: Text('VSL'), icon: Icon(Icons.directions_car)),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            gap,
            TextFormField(
              controller: _driver,
              decoration: const InputDecoration(labelText: 'Chauffeur / équipage (optionnel)'),
            ),
            gap,
            TextFormField(
              controller: _driverPhone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Téléphone du chauffeur (optionnel)'),
              validator: Validators.phone,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Enregistrement…' : 'Enregistrer')),
          ],
        ),
      ),
    );
  }
}
