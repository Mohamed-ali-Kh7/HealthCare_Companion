import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/notifications/reminder_service.dart';
import '../../core/utils/formatters.dart';
import '../../models/medication.dart';
import '../../models/prescription.dart';
import '../../services/medication_service.dart';
import '../../services/prescription_service.dart';
import '../../widgets/async_view.dart';
import '../../widgets/medication_card.dart';
import '../../widgets/ui_helpers.dart';
import 'medication_form_screen.dart';
import 'prescription_details_screen.dart';

/// Ordonnances reçues + carnet de suivi (traitements et rappels).
class TreatmentsScreen extends StatelessWidget {
  const TreatmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(tabs: [
            Tab(icon: Icon(Icons.medication), text: 'Mon carnet'),
            Tab(icon: Icon(Icons.receipt_long), text: 'Ordonnances'),
          ]),
          Expanded(
            child: TabBarView(children: [_MedicationsTab(), _PrescriptionsTab()]),
          ),
        ],
      ),
    );
  }
}

class _MedicationsTab extends StatefulWidget {
  const _MedicationsTab();

  @override
  State<_MedicationsTab> createState() => _MedicationsTabState();
}

class _MedicationsTabState extends State<_MedicationsTab> {
  /// Change de valeur pour forcer le rechargement après ajout / modification.
  Key _viewKey = UniqueKey();

  Future<List<Medication>> _load() async {
    final reminders = context.read<ReminderService>();
    final medications = await context.read<MedicationService>().getMine();
    // Les rappels locaux suivent toujours l'état du carnet côté serveur
    unawaited(reminders.syncWithMedications(medications));
    return medications;
  }

  Future<void> _openForm([Medication? medication]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => MedicationFormScreen(medication: medication)),
    );
    if (changed == true && mounted) setState(() => _viewKey = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      body: AsyncView<List<Medication>>(
        key: _viewKey,
        load: _load,
        builder: (context, medications, reload) => RefreshableList(
          onRefresh: reload,
          itemCount: medications.length,
          empty: const EmptyState(
            icon: Icons.medication_outlined,
            message: 'Votre carnet est vide.\nLes traitements prescrits apparaissent ici automatiquement.',
          ),
          itemBuilder: (context, i) {
            final m = medications[i];
            return MedicationCard(
              medication: m,
              onTap: () => _openForm(m),
              onDelete: () async {
                final ok = await confirm(context,
                    title: 'Supprimer ce traitement ?',
                    message: 'Les rappels associés seront supprimés.',
                    confirmLabel: 'Supprimer',
                    destructive: true);
                if (!ok || !context.mounted) return;
                final done = await runWithFeedback(
                  context,
                  () => context.read<MedicationService>().delete(m.id),
                  successMessage: 'Traitement supprimé',
                );
                if (done) await reload();
              },
            );
          },
        ),
      ),
    );
  }
}

class _PrescriptionsTab extends StatelessWidget {
  const _PrescriptionsTab();

  @override
  Widget build(BuildContext context) {
    return AsyncView<List<Prescription>>(
      load: context.read<PrescriptionService>().getMine,
      builder: (context, prescriptions, reload) => RefreshableList(
        onRefresh: reload,
        itemCount: prescriptions.length,
        empty: const EmptyState(icon: Icons.receipt_long, message: 'Aucune ordonnance pour le moment'),
        itemBuilder: (context, i) {
          final p = prescriptions[i];
          return Card(
            child: ListTile(
              leading: const Icon(Icons.receipt_long),
              title: Text('${p.doctorName} · ${p.doctorSpeciality}'),
              subtitle: Text('${Fmt.date(p.date)} · ${p.items.length} médicament(s)'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => PrescriptionDetailsScreen(prescription: p)),
              ),
            ),
          );
        },
      ),
    );
  }
}
