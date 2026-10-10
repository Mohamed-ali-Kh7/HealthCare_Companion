import 'package:flutter/material.dart';

import '../core/utils/formatters.dart';
import '../models/medication.dart';
import 'status_chip.dart';

class MedicationCard extends StatelessWidget {
  const MedicationCard({super.key, required this.medication, this.onTap, this.onDelete});

  final Medication medication;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final m = medication;
    final theme = Theme.of(context);
    final (label, color) = m.ongoing
        ? ('En cours', Colors.green)
        : (m.active ? ('Planifié / terminé', Colors.blueGrey) : ('Suspendu', Colors.grey));

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
                  Icon(Icons.medication, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('${m.medicine.name} ${m.medicine.strength}',
                        style: theme.textTheme.titleMedium),
                  ),
                  StatusChip(label: label, color: color),
                ],
              ),
              const SizedBox(height: 6),
              Text('${m.actualDosage} · ${m.timesPerDay} fois/jour · ${m.medicine.formLabel}'),
              Text(
                m.endDate == null
                    ? 'Depuis le ${Fmt.date(m.startDate)} (au long cours)'
                    : 'Du ${Fmt.date(m.startDate)} au ${Fmt.date(m.endDate)}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.alarm, size: 18),
                  const SizedBox(width: 6),
                  Expanded(child: Text(m.reminderTimes.join('  ·  '))),
                  if (m.fromPrescription)
                    const Tooltip(message: 'Issu d\'une ordonnance', child: Icon(Icons.receipt_long, size: 18)),
                  if (onDelete != null)
                    IconButton(
                      tooltip: 'Supprimer',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: onDelete,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
