import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/calls/call_service.dart';
import '../../models/ambulance_request.dart';
import '../../services/ambulance_service.dart';
import '../../services/doctor_service.dart';
import '../../widgets/ambulance_request_card.dart';
import '../../widgets/async_view.dart';
import '../../widgets/ui_helpers.dart';

/// Vue médecin : urgences de ses patients (à prendre en charge) et transports à valider.
class DoctorAmbulanceScreen extends StatefulWidget {
  const DoctorAmbulanceScreen({super.key});

  @override
  State<DoctorAmbulanceScreen> createState() => _DoctorAmbulanceScreenState();
}

class _DoctorAmbulanceScreenState extends State<DoctorAmbulanceScreen> {
  /// Rechargement de la liste fourni par AsyncView (utilisé pour les mises à jour en direct).
  Future<void> Function()? _reload;
  final List<StreamSubscription<AmbulanceRequest>> _live = [];

  @override
  void initState() {
    super.initState();
    // Nouvelle urgence ou demande de transport poussée par le serveur : la liste se met à jour seule
    final calls = context.read<CallService>();
    for (final stream in [calls.emergencies, calls.transportRequests, calls.missionUpdates]) {
      _live.add(stream.listen((_) => _reload?.call()));
    }
  }

  @override
  void dispose() {
    for (final s in _live) {
      s.cancel();
    }
    super.dispose();
  }

  /// Pour savoir si une demande m'est adressée / si j'ai pris l'urgence en charge.
  Future<({int myDoctorId, List<AmbulanceRequest> requests})> _load() async {
    final ambulance = context.read<AmbulanceService>();
    final me = await context.read<DoctorService>().getMyProfile();
    final requests = await ambulance.getForDoctor();
    // Urgences en cours d'abord, puis demandes à valider, puis l'historique
    int rank(AmbulanceRequest r) => switch (r.status) {
          AmbulanceRequestStatus.dispatched => 0,
          AmbulanceRequestStatus.pending => 1,
          AmbulanceRequestStatus.approved => 2,
          _ => 3,
        };
    final sorted = [...requests]..sort((a, b) {
        final byRank = rank(a).compareTo(rank(b));
        return byRank != 0 ? byRank : b.createdAt.compareTo(a.createdAt);
      });
    return (myDoctorId: me.id, requests: sorted);
  }

  Future<void> _act(Future<Object?> Function() action, String success, Future<void> Function() reload) async {
    final ok = await runWithFeedback(context, action, successMessage: success);
    if (ok) await reload();
  }

  List<Widget> _actionsFor(AmbulanceRequest r, int myDoctorId, Future<void> Function() reload) {
    final service = context.read<AmbulanceService>();
    final mine = r.doctor?.id == myDoctorId;

    Future<String?> note(String title, String label) =>
        promptText(context, title: title, hint: 'Optionnel', confirmLabel: label);

    if (r.isEmergency && r.status == AmbulanceRequestStatus.dispatched) {
      return [
        if (r.doctor == null)
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () async {
              final n = await note('Prise en charge', 'Je prends en charge');
              if (n == null || !mounted) return;
              await _act(() => service.takeCharge(r.id, note: n.isEmpty ? null : n), 'Urgence prise en charge', reload);
            },
            child: const Text('Prendre en charge'),
          ),
        if (mine)
          FilledButton.tonal(
            onPressed: () => _act(() => service.close(r.id), 'Urgence clôturée', reload),
            child: const Text('Clôturer'),
          ),
      ];
    }
    if (!mine) return const [];
    switch (r.status) {
      case AmbulanceRequestStatus.pending:
        return [
          TextButton(
            onPressed: () async {
              final n = await note('Motif du refus', 'Refuser');
              if (n == null || !mounted) return;
              await _act(() => service.reject(r.id, note: n.isEmpty ? null : n), 'Transport refusé', reload);
            },
            child: const Text('Refuser'),
          ),
          FilledButton.tonal(
            onPressed: () async {
              final n = await note('Consigne pour le transport', 'Valider');
              if (n == null || !mounted) return;
              await _act(() => service.approve(r.id, note: n.isEmpty ? null : n), 'Transport validé', reload);
            },
            child: const Text('Valider'),
          ),
        ];
      case AmbulanceRequestStatus.approved:
        return [
          // Société engagée (véhicule affecté) : c'est elle qui clôture le transport à l'arrivée
          if (r.canBeClosed)
            FilledButton.tonal(
              onPressed: () => _act(() => service.close(r.id), 'Transport clôturé', reload),
              child: const Text('Transport effectué'),
            ),
        ];
      default:
        return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return AsyncView<({int myDoctorId, List<AmbulanceRequest> requests})>(
      load: _load,
      builder: (context, data, reload) {
        _reload = reload;
        return RefreshableList(
          onRefresh: reload,
          itemCount: data.requests.length,
          empty:
              const EmptyState(icon: Icons.local_hospital_outlined, message: 'Aucune urgence ni demande de transport'),
          itemBuilder: (context, i) {
            final r = data.requests[i];
            return AmbulanceRequestCard(
              request: r,
              forDoctor: true,
              actions: _actionsFor(r, data.myDoctorId, reload),
            );
          },
        );
      },
    );
  }
}
