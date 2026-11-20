import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/appointment.dart';
import '../../models/stats.dart';
import '../../services/stats_service.dart';
import '../../widgets/async_view.dart';
import '../../widgets/stat_widgets.dart';

/// Statistiques d'activité du médecin : patientèle, planning, prescriptions, urgences.
class DoctorStatsScreen extends StatelessWidget {
  const DoctorStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes statistiques')),
      body: AsyncView<DoctorStats>(
        load: context.read<StatsService>().getDoctorStats,
        builder: (context, s, reload) {
          final theme = Theme.of(context);
          final totalAppointments = s.appointmentsByStatus.values.fold<int>(0, (x, y) => x + y);
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                StatGrid(
                  children: [
                    StatTile(
                      icon: Icons.emergency,
                      label: 'Urgences en cours',
                      value: '${s.activeEmergencies}',
                      highlight: s.activeEmergencies > 0,
                    ),
                    StatTile(
                      icon: Icons.airport_shuttle,
                      label: 'Transports à valider',
                      value: '${s.pendingTransportValidations}',
                      highlight: s.pendingTransportValidations > 0,
                    ),
                    StatTile(icon: Icons.people, label: 'Patients suivis', value: '${s.patientsFollowed}'),
                    StatTile(icon: Icons.today, label: "RDV aujourd'hui", value: '${s.appointmentsToday}'),
                    StatTile(
                      icon: Icons.thumb_up_alt_outlined,
                      label: "Taux d'acceptation",
                      value: s.acceptanceRate == null ? '—' : '${s.acceptanceRate!.toStringAsFixed(0)} %',
                    ),
                    StatTile(
                      icon: Icons.task_alt,
                      label: 'Consultations ce mois',
                      value: '${s.consultationsThisMonth}',
                    ),
                    StatTile(icon: Icons.receipt_long, label: 'Ordonnances', value: '${s.prescriptionsIssued}'),
                    StatTile(
                      icon: Icons.edit_note,
                      label: 'Ordonnances ce mois',
                      value: '${s.prescriptionsThisMonth}',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Rendez-vous · 7 prochains jours', style: theme.textTheme.titleMedium),
                        DailyBarChart(
                          points: s.upcomingPerDay,
                          unit: 'RDV',
                          emptyMessage: 'Aucun rendez-vous prévu cette semaine',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (totalAppointments > 0)
                  BreakdownCard(
                    title: 'Rendez-vous par statut ($totalAppointments)',
                    rows: [
                      for (final st in AppointmentStatus.values) (st.label, s.appointmentsByStatus[st.apiValue] ?? 0),
                    ],
                  ),
                if (s.topMedicines.isNotEmpty)
                  BreakdownCard(
                    title: 'Médicaments les plus prescrits',
                    labelWidth: 150,
                    rows: [for (final m in s.topMedicines) (m.label, m.count)],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
