import 'package:flutter/material.dart';

import '../core/utils/formatters.dart';
import '../models/appointment.dart';
import 'status_chip.dart';

/// Carte de rendez-vous. [showPatient] : vue médecin (affiche le patient au lieu du médecin).
class AppointmentCard extends StatelessWidget {
  const AppointmentCard({
    super.key,
    required this.appointment,
    this.showPatient = false,
    this.actions = const [],
    this.onTap,
  });

  final Appointment appointment;
  final bool showPatient;
  final List<Widget> actions;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.event, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${Fmt.date(a.date)} à ${Fmt.time(a.date)}',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  StatusChip(label: a.status.label, color: a.status.color),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                showPatient ? a.patient.fullName : '${a.doctor.fullName} · ${a.doctor.specialityName}',
                style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (!showPatient) Text(a.doctor.address, style: theme.textTheme.bodySmall),
              if (a.reason != null) ...[
                const SizedBox(height: 4),
                Text('Motif : ${a.reason}'),
              ],
              if (a.doctorNote != null) ...[
                const SizedBox(height: 4),
                Text('Note du médecin : ${a.doctorNote}',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
              ],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(alignment: WrapAlignment.end, spacing: 8, children: actions),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
