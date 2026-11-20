import 'package:flutter/material.dart';

import '../core/utils/formatters.dart';
import '../core/utils/launcher.dart';
import '../models/ambulance_request.dart';
import 'mission_panel.dart';
import 'status_chip.dart';
import 'ui_helpers.dart';

/// Carte de demande d'ambulance. [forDoctor] : affiche le patient et ses informations médicales.
class AmbulanceRequestCard extends StatelessWidget {
  const AmbulanceRequestCard({
    super.key,
    required this.request,
    this.forDoctor = false,
    this.actions = const [],
  });

  final AmbulanceRequest request;
  final bool forDoctor;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final theme = Theme.of(context);
    final urgent = r.isEmergency && r.status == AmbulanceRequestStatus.dispatched;

    return Card(
      shape: urgent
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16), side: BorderSide(color: theme.colorScheme.error, width: 2))
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(r.isEmergency ? Icons.emergency : Icons.airport_shuttle,
                    color: r.isEmergency ? theme.colorScheme.error : theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(r.type.label, style: theme.textTheme.titleMedium)),
                StatusChip(label: r.status.label, color: r.status.color),
              ],
            ),
            const SizedBox(height: 8),
            if (forDoctor) ...[
              Text(r.patient.fullName, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
              _MedicalInfo(patient: r.patient),
            ],
            Text(r.isEmergency
                ? 'Déclenchée le ${Fmt.dateTime(r.createdAt)}'
                : 'Prévu le ${Fmt.date(r.scheduledAt)} à ${Fmt.time(r.scheduledAt!)}'),
            if (r.address != null) Text('Adresse : ${r.address}'),
            if (r.reason != null) Text('Motif : ${r.reason}'),
            if (r.doctor != null)
              Text(r.isEmergency ? 'Prise en charge : Dr ${r.doctor!.fullName}' : 'Médecin : Dr ${r.doctor!.fullName}'),
            if (r.doctorNote != null)
              Text('Note du médecin : ${r.doctorNote}', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            if (forDoctor && (r.hasLocation || r.patient.phone != null)) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: [
                  if (r.patient.phone != null)
                    OutlinedButton.icon(
                      onPressed: () => _launch(context, Launcher.call(r.patient.phone!)),
                      icon: const Icon(Icons.phone),
                      label: const Text('Appeler'),
                    ),
                  if (r.hasLocation)
                    OutlinedButton.icon(
                      onPressed: () => _launch(context, Launcher.openMap(r.latitude!, r.longitude!)),
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Position'),
                    ),
                ],
              ),
            ],
            if (r.mission != null)
              MissionPanel(
                mission: r.mission!,
                // Appel intégré : patient ↔ société uniquement (le backend refuse le médecin) ;
                // le médecin garde les numéros de téléphone de la société et du chauffeur
                requestId: forDoctor ? null : r.id,
                // Transport annulé ou clôturé : plus de contact à proposer
                showContacts: r.status == AmbulanceRequestStatus.approved,
              ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(alignment: WrapAlignment.end, spacing: 8, children: actions),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _launch(BuildContext context, Future<bool> launch) async {
    if (!await launch && context.mounted) {
      showSnack(context, 'Action impossible sur cet appareil', isError: true);
    }
  }
}

class _MedicalInfo extends StatelessWidget {
  const _MedicalInfo({required this.patient});

  final AmbulancePatientInfo patient;

  @override
  Widget build(BuildContext context) {
    final items = [
      if (patient.bloodGroup != null) 'Groupe sanguin : ${patient.bloodGroup}',
      if (patient.allergies != null) 'Allergies : ${patient.allergies}',
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(items.join(' · '),
          style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600)),
    );
  }
}
