import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/appointment.dart';
import '../../services/appointment_service.dart';
import '../../widgets/appointment_card.dart';
import '../../widgets/async_view.dart';
import '../../widgets/ui_helpers.dart';
import 'patient_record_screen.dart';

/// Planning du médecin : demandes à traiter, rendez-vous acceptés, historique.
class DoctorAppointmentsScreen extends StatefulWidget {
  const DoctorAppointmentsScreen({super.key});

  @override
  State<DoctorAppointmentsScreen> createState() => _DoctorAppointmentsScreenState();
}

class _DoctorAppointmentsScreenState extends State<DoctorAppointmentsScreen> {
  static const _filters = <AppointmentStatus?>[
    AppointmentStatus.pending,
    AppointmentStatus.accepted,
    AppointmentStatus.completed,
    null,
  ];

  AppointmentStatus? _status = AppointmentStatus.pending;
  Key _viewKey = UniqueKey();

  Future<List<Appointment>> _load() {
    final today = DateTime.now();
    // "À venir" pour les demandes et RDV acceptés ; tout l'historique sinon
    final from = (_status == AppointmentStatus.pending || _status == AppointmentStatus.accepted)
        ? DateTime(today.year, today.month, today.day)
        : null;
    return context.read<AppointmentService>().getDoctorAppointments(status: _status, from: from);
  }

  Future<void> _act(Future<Object?> Function() action, String success, Future<void> Function() reload) async {
    final ok = await runWithFeedback(context, action, successMessage: success);
    if (ok) await reload();
  }

  List<Widget> _actionsFor(Appointment a, Future<void> Function() reload) {
    final service = context.read<AppointmentService>();
    switch (a.status) {
      case AppointmentStatus.pending:
        return [
          TextButton(
            onPressed: () async {
              final note = await promptText(context,
                  title: 'Motif du refus', hint: 'Optionnel', confirmLabel: 'Refuser');
              if (note == null || !mounted) return;
              await _act(() => service.reject(a.id, note: note.isEmpty ? null : note), 'Rendez-vous refusé', reload);
            },
            child: const Text('Refuser'),
          ),
          FilledButton.tonal(
            onPressed: () => _act(() => service.accept(a.id), 'Rendez-vous accepté', reload),
            child: const Text('Accepter'),
          ),
        ];
      case AppointmentStatus.accepted:
        return [
          FilledButton.tonal(
            onPressed: () async {
              final note = await promptText(context,
                  title: 'Compte rendu', hint: 'Optionnel', confirmLabel: 'Terminer');
              if (note == null || !mounted) return;
              await _act(() => service.complete(a.id, note: note.isEmpty ? null : note),
                  'Consultation terminée', reload);
            },
            child: const Text('Terminer'),
          ),
        ];
      default:
        return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            children: [
              for (final f in _filters)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(f?.label ?? 'Tous'),
                    selected: _status == f,
                    onSelected: (_) => setState(() {
                      _status = f;
                      _viewKey = UniqueKey();
                    }),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: AsyncView<List<Appointment>>(
            key: _viewKey,
            load: _load,
            builder: (context, appointments, reload) => RefreshableList(
              onRefresh: reload,
              itemCount: appointments.length,
              empty: const EmptyState(icon: Icons.event_available, message: 'Aucun rendez-vous'),
              itemBuilder: (context, i) {
                final a = appointments[i];
                return AppointmentCard(
                  appointment: a,
                  showPatient: true,
                  actions: _actionsFor(a, reload),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => PatientRecordScreen(patientId: a.patient.id),
                  )),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
