import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/appointment.dart';
import '../../models/dashboard.dart';
import '../../models/user.dart';
import '../../services/admin_service.dart';
import '../../widgets/async_view.dart';

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
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.6,
                children: [
                  _StatTile(icon: Icons.people, label: 'Utilisateurs', value: totalUsers),
                  _StatTile(
                    icon: Icons.hourglass_top,
                    label: 'En attente / désactivés',
                    value: d.pendingOrDisabledAccounts,
                    highlight: d.pendingOrDisabledAccounts > 0,
                  ),
                  _StatTile(icon: Icons.event, label: 'Rendez-vous', value: totalAppointments),
                  _StatTile(icon: Icons.local_pharmacy, label: 'Pharmacies', value: d.pharmacies),
                  _StatTile(icon: Icons.medication, label: 'Médicaments', value: d.medicines),
                  _StatTile(icon: Icons.sensors, label: 'Mesures (24 h)', value: d.sensorReadingsLast24h),
                ],
              ),
              const SizedBox(height: 16),
              _Breakdown(
                title: 'Comptes par rôle',
                total: totalUsers,
                rows: [for (final r in UserRole.values) (r.label, d.usersByRole[r.apiValue] ?? 0)],
              ),
              _Breakdown(
                title: 'Rendez-vous par statut',
                total: totalAppointments,
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

class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.label, required this.value, this.highlight = false});

  final IconData icon;
  final String label;
  final int value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: highlight ? scheme.tertiaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: scheme.primary),
            Text('$value', style: Theme.of(context).textTheme.headlineSmall),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

/// Répartition horizontale : libellé, barre proportionnelle, valeur.
class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.title, required this.total, required this.rows});

  final String title;
  final int total;
  final List<(String, int)> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(width: 120, child: Text(label)),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : value / total,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    SizedBox(width: 40, child: Text('$value', textAlign: TextAlign.end)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
