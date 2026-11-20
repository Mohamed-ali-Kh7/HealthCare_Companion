import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../models/appointment.dart';
import '../../models/stats.dart';
import '../../services/stats_service.dart';
import '../../widgets/appointment_card.dart';
import '../../widgets/async_view.dart';
import '../../widgets/stat_widgets.dart';

/// Statistiques personnelles du patient : suivi médical et activité des 7 derniers jours.
class PatientStatsScreen extends StatelessWidget {
  const PatientStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes statistiques')),
      body: AsyncView<PatientStats>(
        load: context.read<StatsService>().getPatientStats,
        builder: (context, s, reload) {
          final a = s.activity;
          final totalAppointments = s.appointmentsByStatus.values.fold<int>(0, (x, y) => x + y);
          final theme = Theme.of(context);
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Prochain rendez-vous', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                if (s.nextAppointment != null)
                  AppointmentCard(appointment: s.nextAppointment!)
                else
                  const Card(
                      child: ListTile(leading: Icon(Icons.event_busy), title: Text('Aucun rendez-vous à venir'))),
                const SizedBox(height: 16),
                Text('Activité · 7 derniers jours', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                StatGrid(
                  children: [
                    StatTile(icon: Icons.directions_walk, label: "Pas aujourd'hui", value: '${a.stepsToday}'),
                    StatTile(
                      icon: Icons.trending_up,
                      label: 'Pas / jour en moyenne',
                      value: a.daysWithSteps == 0 ? '—' : '${a.averageDailySteps}',
                    ),
                    StatTile(
                      icon: Icons.monitor_heart,
                      label: 'Fréquence cardiaque moy.',
                      value: a.averageHeartRate == null ? '—' : '${a.averageHeartRate!.toStringAsFixed(0)} bpm',
                    ),
                    StatTile(
                      icon: Icons.calendar_view_week,
                      label: 'Jours mesurés',
                      value: '${a.daysWithSteps} / ${a.stepsPerDay.length}',
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
                        Text('Pas par jour', style: theme.textTheme.titleMedium),
                        if (a.bestDay != null)
                          Text('Meilleur jour : ${Fmt.dateLong(a.bestDay!)} · ${a.bestDaySteps} pas',
                              style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                        DailyBarChart(
                          points: a.stepsPerDay,
                          unit: 'pas',
                          emptyMessage: "Aucune mesure : activez le suivi dans l'onglet Santé",
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Suivi médical', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                StatGrid(
                  children: [
                    StatTile(icon: Icons.medication, label: 'Traitements en cours', value: '${s.ongoingMedications}'),
                    StatTile(icon: Icons.receipt_long, label: 'Ordonnances', value: '${s.prescriptions}'),
                    StatTile(icon: Icons.medical_services, label: 'Médecins consultés', value: '${s.doctorsConsulted}'),
                    StatTile(
                        icon: Icons.local_hospital, label: "Demandes d'ambulance", value: '${s.ambulanceRequests}'),
                  ],
                ),
                const SizedBox(height: 12),
                if (totalAppointments > 0)
                  BreakdownCard(
                    title: 'Mes rendez-vous ($totalAppointments)',
                    rows: [
                      for (final st in AppointmentStatus.values) (st.label, s.appointmentsByStatus[st.apiValue] ?? 0),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
