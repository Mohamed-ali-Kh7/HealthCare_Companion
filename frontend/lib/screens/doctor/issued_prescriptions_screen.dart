import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../models/prescription.dart';
import '../../services/prescription_service.dart';
import '../../widgets/async_view.dart';
import '../patient/prescription_details_screen.dart';

/// Ordonnances émises par le médecin connecté.
class IssuedPrescriptionsScreen extends StatelessWidget {
  const IssuedPrescriptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AsyncView<List<Prescription>>(
      load: context.read<PrescriptionService>().getIssuedByMe,
      builder: (context, prescriptions, reload) => RefreshableList(
        onRefresh: reload,
        itemCount: prescriptions.length,
        empty: const EmptyState(
          icon: Icons.receipt_long,
          message: 'Aucune ordonnance émise.\nOuvrez le dossier d\'un patient pour prescrire.',
        ),
        itemBuilder: (context, i) {
          final p = prescriptions[i];
          return Card(
            child: ListTile(
              leading: const Icon(Icons.receipt_long),
              title: Text(p.patient.fullName),
              subtitle: Text('${Fmt.date(p.date)} · ${p.items.length} médicament(s)'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => PrescriptionDetailsScreen(prescription: p, showPharmacySearch: false),
              )),
            ),
          );
        },
      ),
    );
  }
}
