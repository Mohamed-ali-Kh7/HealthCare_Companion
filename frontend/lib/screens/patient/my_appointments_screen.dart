import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/appointment.dart';
import '../../services/appointment_service.dart';
import '../../widgets/appointment_card.dart';
import '../../widgets/async_view.dart';
import '../../widgets/ui_helpers.dart';

class MyAppointmentsScreen extends StatelessWidget {
  const MyAppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<AppointmentService>();
    return AsyncView<List<Appointment>>(
      load: service.getMine,
      builder: (context, appointments, reload) {
        final upcoming = appointments.where((a) => a.isUpcoming).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
        final past = appointments.where((a) => !a.isUpcoming).toList();
        final items = <Widget>[
          if (upcoming.isNotEmpty) const _Section('À venir'),
          for (final a in upcoming) _card(context, a, reload),
          if (past.isNotEmpty) const _Section('Historique'),
          for (final a in past) _card(context, a, reload),
        ];
        return RefreshableList(
          onRefresh: reload,
          itemCount: items.length,
          itemBuilder: (_, i) => items[i],
          empty: const EmptyState(
            icon: Icons.event_busy,
            message: 'Aucun rendez-vous.\nRecherchez un médecin pour en prendre un.',
          ),
        );
      },
    );
  }

  Widget _card(BuildContext context, Appointment a, Future<void> Function() reload) {
    return AppointmentCard(
      appointment: a,
      actions: [
        if (a.canBeCancelled)
          TextButton.icon(
            icon: const Icon(Icons.close),
            label: const Text('Annuler'),
            onPressed: () async {
              final ok = await confirm(context,
                  title: 'Annuler le rendez-vous ?',
                  message: 'Le créneau sera libéré pour d\'autres patients.',
                  confirmLabel: 'Annuler le RDV',
                  destructive: true);
              if (!ok || !context.mounted) return;
              final done = await runWithFeedback(
                context,
                () => context.read<AppointmentService>().cancel(a.id),
                successMessage: 'Rendez-vous annulé',
              );
              if (done) await reload();
            },
          ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
        child: Text(title, style: Theme.of(context).textTheme.titleSmall),
      );
}
