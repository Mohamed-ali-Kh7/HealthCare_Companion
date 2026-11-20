import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/appointment.dart';
import '../../models/dashboard.dart';
import '../../models/user.dart';
import '../../services/admin_service.dart';
import '../../widgets/async_view.dart';
import '../../widgets/stat_widgets.dart';

/// Tableau de bord de supervision de la plateforme.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AsyncView<Dashboard>(
      load: context.read<AdminService>().getDashboard,
      builder: (context, d, reload) {
        final totalUsers = d.usersByRole.values.fold<int>(0, (a, b) => a + b);
        final totalAppointments = d.appointmentsByStatus.values.fold<int>(0, (a, b) => a + b);
        return RefreshIndicator(
          onRefresh: reload,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              StatGrid(
                children: [
                  StatTile(icon: Icons.people, label: 'Utilisateurs', value: '$totalUsers'),
                  StatTile(
                    icon: Icons.hourglass_top,
                    label: 'En attente / désactivés',
                    value: '${d.pendingOrDisabledAccounts}',
                    highlight: d.pendingOrDisabledAccounts > 0,
                  ),
                  StatTile(icon: Icons.event, label: 'Rendez-vous', value: '$totalAppointments'),
                  StatTile(icon: Icons.local_pharmacy, label: 'Pharmacies', value: '${d.pharmacies}'),
                  StatTile(icon: Icons.medication, label: 'Médicaments', value: '${d.medicines}'),
                  StatTile(icon: Icons.sensors, label: 'Mesures (24 h)', value: '${d.sensorReadingsLast24h}'),
                ],
              ),
              const SizedBox(height: 16),
              BreakdownCard(
                title: 'Comptes par rôle',
                rows: [for (final r in UserRole.values) (r.label, d.usersByRole[r.apiValue] ?? 0)],
              ),
              BreakdownCard(
                title: 'Rendez-vous par statut',
                rows: [
                  for (final s in AppointmentStatus.values) (s.label, d.appointmentsByStatus[s.apiValue] ?? 0),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
