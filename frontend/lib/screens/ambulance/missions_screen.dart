import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/calls/call_service.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/launcher.dart';
import '../../models/ambulance_request.dart';
import '../../models/transport.dart';
import '../../services/transport_service.dart';
import '../../widgets/async_view.dart';
import '../../widgets/mission_panel.dart';
import '../../widgets/ui_helpers.dart';

/// Société : transports confiés par les patients. À accepter (avec un véhicule) ou refuser, puis suivi étape par étape.
class MissionsScreen extends StatefulWidget {
  const MissionsScreen({super.key});

  @override
  State<MissionsScreen> createState() => _MissionsScreenState();
}

class _MissionsScreenState extends State<MissionsScreen> {
  Future<void> Function()? _reload;
  StreamSubscription<AmbulanceRequest>? _live;

  @override
  void initState() {
    super.initState();
    // Le bandeau de notification est affiché par CallOverlay ; ici, la liste se met à jour
    _live = context.read<CallService>().missionUpdates.listen((_) => _reload?.call());
  }

  @override
  void dispose() {
    _live?.cancel();
    super.dispose();
  }

  Future<void> _accept(AmbulanceRequest r, Future<void> Function() reload) async {
    final service = context.read<TransportService>();
    final vehicles = (await service.getVehicles()).where((v) => v.inService).toList();
    if (!mounted) return;
    if (vehicles.isEmpty) {
      showSnack(context, 'Aucun véhicule en service : ajoutez-en un dans l\'onglet Flotte.', isError: true);
      return;
    }
    final choice = await showModalBottomSheet<({AmbulanceVehicle vehicle, String? note})>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AcceptSheet(request: r, vehicles: vehicles),
    );
    if (choice == null || !mounted) return;
    final ok = await runWithFeedback(context, () => service.acceptMission(r.id, choice.vehicle.id, note: choice.note),
        successMessage: 'Mission acceptée : ${choice.vehicle.plate}');
    if (ok) await reload();
  }

  Future<void> _refuse(AmbulanceRequest r, Future<void> Function() reload) async {
    final note = await promptText(context,
        title: 'Refuser le transport ?', hint: 'Motif (ex : aucun véhicule disponible à cette heure)', confirmLabel: 'Refuser');
    if (note == null || !mounted) return;
    final ok = await runWithFeedback(
        context, () => context.read<TransportService>().refuseMission(r.id, note: note.isEmpty ? null : note),
        successMessage: 'Transport refusé : le patient peut choisir une autre société');
    if (ok) await reload();
  }

  Future<void> _advance(AmbulanceRequest r, Future<void> Function() reload) async {
    final label = r.mission!.status.nextActionLabel!;
    final ok = await runWithFeedback(context, () => context.read<TransportService>().advanceMission(r.id),
        successMessage: '$label : patient et médecin prévenus');
    if (ok) await reload();
  }

  @override
  Widget build(BuildContext context) {
    return AsyncView<List<AmbulanceRequest>>(
      load: () => context.read<TransportService>().getMissions(),
      builder: (context, missions, reload) {
        _reload = reload;
        // À accepter d'abord, puis en cours, planifiées, et enfin terminées / refusées
        int rank(AmbulanceRequest r) => switch (r.mission?.status) {
              MissionStatus.requested => 0,
              MissionStatus.enRoute || MissionStatus.onSite || MissionStatus.inTransit => 1,
              MissionStatus.accepted => 2,
              _ => 3,
            };
        final sorted = [...missions]..sort((a, b) {
            final byRank = rank(a).compareTo(rank(b));
            return byRank != 0 ? byRank : (a.scheduledAt ?? a.createdAt).compareTo(b.scheduledAt ?? b.createdAt);
          });
        final pending = missions.where((m) => m.mission?.status == MissionStatus.requested).length;
        return RefreshableList(
          onRefresh: reload,
          itemCount: sorted.length,
          header: pending == 0
              ? null
              : Card(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.notifications_active_outlined),
                    title: Text('$pending demande(s) à traiter'),
                  ),
                ),
          empty: const EmptyState(
            icon: Icons.assignment_outlined,
            message: 'Aucune mission pour le moment.\nLes patients vous confient leurs transports validés par leur médecin.',
          ),
          itemBuilder: (context, i) => _MissionCard(
            request: sorted[i],
            onAccept: () => _accept(sorted[i], reload),
            onRefuse: () => _refuse(sorted[i], reload),
            onAdvance: () => _advance(sorted[i], reload),
          ),
        );
      },
    );
  }
}

class _MissionCard extends StatelessWidget {
  const _MissionCard({required this.request, required this.onAccept, required this.onRefuse, required this.onAdvance});

  final AmbulanceRequest request;
  final VoidCallback onAccept;
  final VoidCallback onRefuse;
  final VoidCallback onAdvance;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final m = r.mission!;
    final theme = Theme.of(context);
    final p = r.patient;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.event, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(Fmt.dateTime(r.scheduledAt ?? r.createdAt), style: theme.textTheme.titleMedium),
              ),
            ]),
            const SizedBox(height: 6),
            Text(p.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (r.address != null) Text('📍 ${r.address}'),
            if (r.reason != null) Text('Motif : ${r.reason}'),
            if (r.doctor != null) Text('Prescrit par le Dr ${r.doctor!.fullName}'),
            if (r.doctorNote != null)
              Text('Consigne du médecin : ${r.doctorNote}', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            if (p.bloodGroup != null || p.allergies != null)
              Text(
                [
                  if (p.bloodGroup != null) 'Groupe ${p.bloodGroup}',
                  if (p.allergies != null) 'Allergies : ${p.allergies}',
                ].join(' · '),
                style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w600),
              ),
            MissionPanel(mission: m, showContacts: false),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 4,
              children: [
                // Appel dans l'application (fonctionne aussi dans le navigateur), tant que le transport est en cours
                if (m.status != MissionStatus.refused && m.status != MissionStatus.arrived)
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.call, size: 18),
                    label: const Text('Appeler le patient'),
                    onPressed: () => context.read<CallService>().startCall(
                          contactId: 0,
                          missionId: r.id,
                          name: p.fullName,
                          subtitle: 'Patient · transport du ${Fmt.dateTime(r.scheduledAt ?? r.createdAt)}',
                          video: false,
                        ),
                  ),
                if (p.phone != null)
                  TextButton.icon(
                    icon: const Icon(Icons.phone, size: 18),
                    label: Text(p.phone!),
                    onPressed: () async {
                      if (!await Launcher.call(p.phone!) && context.mounted) {
                        showSnack(context, 'Appel impossible sur cet appareil : ${p.phone}', isError: true);
                      }
                    },
                  ),
                if (r.hasLocation && m.status != MissionStatus.arrived)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('Itinéraire'),
                    onPressed: () => Launcher.openMap(r.latitude!, r.longitude!),
                  ),
                if (m.status == MissionStatus.requested) ...[
                  TextButton(onPressed: onRefuse, child: const Text('Refuser')),
                  FilledButton(onPressed: onAccept, child: const Text('Accepter')),
                ],
                if (m.status.nextActionLabel != null)
                  FilledButton.icon(
                    icon: Icon(MissionStatus.values[MissionStatus.values.indexOf(m.status) + 1].icon, size: 18),
                    label: Text(m.status.nextActionLabel!),
                    onPressed: onAdvance,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Choix du véhicule (en service) et message facultatif au patient.
class _AcceptSheet extends StatefulWidget {
  const _AcceptSheet({required this.request, required this.vehicles});

  final AmbulanceRequest request;
  final List<AmbulanceVehicle> vehicles;

  @override
  State<_AcceptSheet> createState() => _AcceptSheetState();
}

class _AcceptSheetState extends State<_AcceptSheet> {
  late AmbulanceVehicle _vehicle = widget.vehicles.first;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: ListView(
        shrinkWrap: true,
        children: [
          Text('Accepter le transport', style: Theme.of(context).textTheme.titleLarge),
          Text('${widget.request.patient.fullName} · ${Fmt.dateTime(widget.request.scheduledAt!)}'),
          const SizedBox(height: 12),
          RadioGroup<int>(
            groupValue: _vehicle.id,
            onChanged: (id) => setState(() => _vehicle = widget.vehicles.firstWhere((v) => v.id == id)),
            child: Column(children: [
              for (final v in widget.vehicles)
                RadioListTile<int>(
                  value: v.id,
                  contentPadding: EdgeInsets.zero,
                  title: Text('${v.plate} · ${v.type.label}'),
                  subtitle: Text(v.driverName ?? 'Équipage non renseigné'),
                ),
            ]),
          ),
          TextField(
            controller: _note,
            maxLength: 500,
            decoration: const InputDecoration(labelText: 'Message au patient (optionnel)', hintText: 'ex : arrivée 10 min avant'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            icon: const Icon(Icons.check),
            label: const Text('Confirmer'),
            onPressed: () => Navigator.of(context)
                .pop((vehicle: _vehicle, note: _note.text.trim().isEmpty ? null : _note.text.trim())),
          ),
        ],
      ),
    );
  }
}
