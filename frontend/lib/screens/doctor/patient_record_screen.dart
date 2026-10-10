import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_exception.dart';
import '../../core/utils/formatters.dart';
import '../../models/patient.dart';
import '../../models/prescription.dart';
import '../../models/sensor.dart';
import '../../services/patient_service.dart';
import '../../services/prescription_service.dart';
import '../../services/telemonitoring_service.dart';
import '../../widgets/async_view.dart';
import '../../widgets/sensor_chart.dart';
import '../../widgets/ui_helpers.dart';
import '../patient/prescription_details_screen.dart';
import 'prescription_form_screen.dart';

/// Dossier patient vu par le médecin : informations, ordonnances, télésuivi.
/// L'API refuse l'accès (403) si le médecin n'a pas de rendez-vous avec ce patient.
class PatientRecordScreen extends StatefulWidget {
  const PatientRecordScreen({super.key, required this.patientId});

  final int patientId;

  @override
  State<PatientRecordScreen> createState() => _PatientRecordScreenState();
}

class _PatientRecordScreenState extends State<PatientRecordScreen> {
  late Future<Patient> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<PatientService>().getById(widget.patientId);
  }

  void _retry() => setState(() => _future = context.read<PatientService>().getById(widget.patientId));

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Patient>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done || snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Dossier patient')),
            body: snapshot.hasError
                ? ErrorState(message: errorMessage(snapshot.error), onRetry: _retry)
                : const Center(child: CircularProgressIndicator()),
          );
        }
        final patient = snapshot.data!;
        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: Text(patient.fullName),
              bottom: const TabBar(tabs: [
                Tab(text: 'Dossier'),
                Tab(text: 'Ordonnances'),
                Tab(text: 'Télésuivi'),
              ]),
            ),
            floatingActionButton: FloatingActionButton.extended(
              icon: const Icon(Icons.edit_note),
              label: const Text('Prescrire'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => PrescriptionFormScreen(patient: patient),
              )),
            ),
            body: TabBarView(children: [
              _InfoTab(patient: patient),
              _PrescriptionsTab(patientId: patient.id),
              _TelemonitoringTab(patientId: patient.id),
            ]),
          ),
        );
      },
    );
  }
}

class _InfoTab extends StatelessWidget {
  const _InfoTab({required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context) {
    final p = patient;
    return ListView(
      children: [
        ListTile(leading: const Icon(Icons.email_outlined), title: Text(p.email)),
        ListTile(leading: const Icon(Icons.phone_outlined), title: Text(p.phone ?? '—')),
        ListTile(
          leading: const Icon(Icons.cake_outlined),
          title: Text(p.dateOfBirth == null ? '—' : '${Fmt.date(p.dateOfBirth)} (${p.age} ans)'),
        ),
        ListTile(
          leading: const Icon(Icons.bloodtype_outlined),
          title: const Text('Groupe sanguin'),
          trailing: Text(p.bloodGroup ?? '—', style: Theme.of(context).textTheme.titleMedium),
        ),
        ListTile(
          leading: Icon(Icons.warning_amber, color: p.allergies == null ? null : Colors.orange),
          title: const Text('Allergies'),
          subtitle: Text(p.allergies ?? 'Aucune déclarée'),
        ),
      ],
    );
  }
}

class _PrescriptionsTab extends StatelessWidget {
  const _PrescriptionsTab({required this.patientId});

  final int patientId;

  @override
  Widget build(BuildContext context) {
    return AsyncView<List<Prescription>>(
      load: () => context.read<PrescriptionService>().getPatientHistory(patientId),
      builder: (context, prescriptions, reload) => RefreshableList(
        onRefresh: reload,
        itemCount: prescriptions.length,
        empty: const EmptyState(icon: Icons.receipt_long, message: 'Aucune ordonnance'),
        itemBuilder: (context, i) {
          final p = prescriptions[i];
          return Card(
            child: ListTile(
              title: Text('${Fmt.date(p.date)} · ${p.doctorName}'),
              subtitle: Text(p.items.map((it) => '${it.medicine.name} ${it.medicine.strength}').join(', ')),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => PrescriptionDetailsScreen(prescription: p, showPharmacySearch: false),
              )),
            ),
          );
        },
      ),
    );
  }
}

class _TelemonitoringTab extends StatefulWidget {
  const _TelemonitoringTab({required this.patientId});

  final int patientId;

  @override
  State<_TelemonitoringTab> createState() => _TelemonitoringTabState();
}

class _TelemonitoringTabState extends State<_TelemonitoringTab> {
  late final Future<List<List<DailySummary>>> _future;

  @override
  void initState() {
    super.initState();
    final service = context.read<TelemonitoringService>();
    _future = Future.wait([
      service.getPatientSummary(widget.patientId, SensorType.steps),
      service.getPatientSummary(widget.patientId, SensorType.heartRate),
      service.getPatientSummary(widget.patientId, SensorType.acceleration),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<List<DailySummary>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final error = snapshot.error;
        if (error is ApiException && error.statusCode == 403) {
          return const EmptyState(
            icon: Icons.lock_outline,
            message: 'Le télésuivi est accessible après acceptation d\'un rendez-vous avec ce patient.',
          );
        }
        if (error != null) {
          return const EmptyState(icon: Icons.cloud_off, message: 'Données indisponibles');
        }
        final data = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            SensorSummaryCard(type: SensorType.steps, data: data[0]),
            SensorSummaryCard(type: SensorType.heartRate, data: data[1]),
            SensorSummaryCard(type: SensorType.acceleration, data: data[2]),
          ],
        );
      },
    );
  }
}
