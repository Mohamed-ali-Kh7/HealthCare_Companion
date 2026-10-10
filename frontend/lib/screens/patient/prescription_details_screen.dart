import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../models/prescription.dart';
import 'medicine_availability_screen.dart';

/// Détail d'une ordonnance. Utilisé côté patient (avec recherche en pharmacie) et côté médecin.
class PrescriptionDetailsScreen extends StatelessWidget {
  const PrescriptionDetailsScreen({
    super.key,
    required this.prescription,
    this.showPharmacySearch = true,
  });

  final Prescription prescription;
  final bool showPharmacySearch;

  @override
  Widget build(BuildContext context) {
    final p = prescription;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Ordonnance du ${Fmt.date(p.date)}')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ListTile(
            leading: const Icon(Icons.medical_services_outlined),
            title: Text(p.doctorName),
            subtitle: Text(p.doctorSpeciality),
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(p.patient.fullName),
            subtitle: const Text('Patient'),
          ),
          if (p.notes != null)
            ListTile(leading: const Icon(Icons.notes), title: Text(p.notes!)),
          const Divider(),
          for (final item in p.items)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${item.medicine.name} ${item.medicine.strength}',
                        style: theme.textTheme.titleMedium),
                    Text(item.medicine.formLabel,
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 6),
                    Text(item.posology),
                    if (item.instructions != null) Text(item.instructions!),
                    if (showPharmacySearch)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          icon: const Icon(Icons.local_pharmacy_outlined),
                          label: const Text('Trouver en pharmacie'),
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => MedicineAvailabilityScreen(medicine: item.medicine),
                          )),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
