import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/patient.dart';
import '../../services/patient_service.dart';
import '../../widgets/async_view.dart';
import 'patient_record_screen.dart';

/// Patients suivis (au moins un rendez-vous en attente, accepté ou terminé).
class DoctorPatientsScreen extends StatelessWidget {
  const DoctorPatientsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AsyncView<List<Patient>>(
      load: context.read<PatientService>().getMyPatients,
      builder: (context, patients, reload) => RefreshableList(
        onRefresh: reload,
        itemCount: patients.length,
        empty: const EmptyState(icon: Icons.people_outline, message: 'Aucun patient suivi pour le moment'),
        itemBuilder: (context, i) {
          final p = patients[i];
          final age = p.age;
          return Card(
            child: ListTile(
              leading: CircleAvatar(child: Text('${p.firstName[0]}${p.lastName[0]}')),
              title: Text(p.fullName),
              subtitle: Text([
                if (age != null) '$age ans',
                if (p.bloodGroup != null) 'Groupe ${p.bloodGroup}',
              ].join(' · ')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => PatientRecordScreen(patientId: p.id)),
              ),
            ),
          );
        },
      ),
    );
  }
}
