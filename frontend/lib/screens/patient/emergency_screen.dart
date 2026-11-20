import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/calls/call_service.dart';
import '../../core/utils/launcher.dart';
import '../../core/utils/location_helper.dart';
import '../../models/ambulance_request.dart';
import '../../services/ambulance_service.dart';
import '../../widgets/ambulance_request_card.dart';
import '../../widgets/async_view.dart';
import '../../widgets/ui_helpers.dart';
import 'choose_ambulance_screen.dart';
import 'emergency_call_screen.dart';
import 'scheduled_transport_form_screen.dart';

/// Espace urgence du patient.
/// L'appel au SAMU reste le geste principal : l'alerte envoyée aux médecins le complète,
/// elle ne le remplace pas (l'application n'est pas reliée à un centre de régulation).
class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  bool _sending = false;
  Future<void> Function()? _reload;
  StreamSubscription<AmbulanceRequest>? _live;

  @override
  void initState() {
    super.initState();
    // Étapes du transport (acceptation, en route, sur place...) : la liste se met à jour en direct
    _live = context.read<CallService>().missionUpdates.listen((_) => _reload?.call());
  }

  @override
  void dispose() {
    _live?.cancel();
    super.dispose();
  }

  Future<List<AmbulanceRequest>> _load() => context.read<AmbulanceService>().getMine();

  Future<void> _call(String number, Future<void> Function() reload) async {
    final label = number == EmergencyNumbers.samu ? 'SAMU' : 'Protection civile';
    final alertSent = await Navigator.of(context).push<bool>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => EmergencyCallScreen(number: number, label: label),
    ));
    if (alertSent == true && mounted) await reload();
  }

  Future<void> _sendEmergency(Future<void> Function() reload) async {
    final service = context.read<AmbulanceService>();
    final ok = await confirm(context,
        title: 'Envoyer une alerte ?',
        message: 'Vos médecins seront prévenus immédiatement avec votre position.\n\n'
            'En cas de danger vital, appelez aussi le SAMU (190).',
        confirmLabel: 'Envoyer',
        destructive: true);
    if (!ok || !mounted) return;
    final reason = await promptText(context,
        title: 'Que se passe-t-il ?', hint: 'Optionnel (ex : douleur thoracique)', confirmLabel: 'Envoyer');
    if (reason == null || !mounted) return;

    setState(() => _sending = true);
    // Pas de position inventée : sans GPS, on n'envoie pas de coordonnées
    final position = await LocationHelper.current();
    if (!mounted) return;
    final sent = await runWithFeedback(
      context,
      () => service.sendEmergency(
        lat: position.isFallback ? null : position.lat,
        lng: position.isFallback ? null : position.lng,
        reason: reason.isEmpty ? null : reason,
      ),
      successMessage: position.isFallback
          ? 'Alerte envoyée (position indisponible). Appelez le 190 si nécessaire.'
          : 'Alerte envoyée à vos médecins avec votre position.',
    );
    if (mounted) setState(() => _sending = false);
    if (sent) await reload();
  }

  Future<void> _act(Future<Object?> Function() action, String success, Future<void> Function() reload) async {
    final ok = await runWithFeedback(context, action, successMessage: success);
    if (ok) await reload();
  }

  List<Widget> _actionsFor(AmbulanceRequest r, Future<void> Function() reload) {
    final service = context.read<AmbulanceService>();
    return [
      if (r.canBeCancelled)
        TextButton(
          onPressed: () async {
            final ok = await confirm(context,
                title: 'Annuler la demande ?',
                message:
                    r.isEmergency ? 'Fausse alerte ou situation résolue sans secours ?' : 'Le transport sera annulé.',
                confirmLabel: 'Annuler la demande',
                destructive: true);
            if (ok && mounted) {
              await _act(() => service.cancel(r.id), 'Demande annulée', reload);
            }
          },
          child: const Text('Annuler'),
        ),
      if (r.canChooseCompany)
        FilledButton.icon(
          icon: const Icon(Icons.airport_shuttle, size: 18),
          label: Text(r.mission == null
              ? 'Choisir une ambulance'
              : r.mission!.status == MissionStatus.refused
                  ? 'Choisir une autre société'
                  : 'Changer de société'),
          onPressed: () async {
            final updated = await Navigator.of(context)
                .push<AmbulanceRequest>(MaterialPageRoute(builder: (_) => ChooseAmbulanceScreen(request: r)));
            if (updated != null && mounted) {
              showSnack(context, 'Demande envoyée à ${updated.mission?.company.name ?? 'la société'}');
              await reload();
            }
          },
        ),
      // Dès qu'une société a affecté un véhicule, c'est elle qui clôture le transport à l'arrivée
      if (r.canBeClosed)
        FilledButton.tonal(
          onPressed: () => _act(() => service.close(r.id), 'Demande clôturée', reload),
          child: Text(r.isEmergency ? 'Je vais bien' : 'Transport effectué'),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return AsyncView<List<AmbulanceRequest>>(
      load: _load,
      builder: (context, requests, reload) {
        _reload = reload;
        final activeEmergency = requests.any((r) => r.isEmergency && r.status == AmbulanceRequestStatus.dispatched);
        return RefreshableList(
          onRefresh: reload,
          header: _Header(
            sending: _sending,
            activeEmergency: activeEmergency,
            onCall: (number) => _call(number, reload),
            onAlert: () => _sendEmergency(reload),
            onTransport: () async {
              final created = await Navigator.of(context)
                  .push<bool>(MaterialPageRoute(builder: (_) => const ScheduledTransportFormScreen()));
              if (created == true) await reload();
            },
          ),
          itemCount: requests.length,
          empty: const EmptyState(icon: Icons.local_hospital_outlined, message: 'Aucune demande'),
          itemBuilder: (context, i) =>
              AmbulanceRequestCard(request: requests[i], actions: _actionsFor(requests[i], reload)),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.sending,
    required this.activeEmergency,
    required this.onCall,
    required this.onAlert,
    required this.onTransport,
  });

  final bool sending;
  final bool activeEmergency;
  final Future<void> Function(String number) onCall;
  final VoidCallback onAlert;
  final VoidCallback onTransport;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final redButton = FilledButton.styleFrom(
      backgroundColor: scheme.error,
      foregroundColor: scheme.onError,
      minimumSize: const Size.fromHeight(56),
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: scheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Danger vital ? Appelez immédiatement',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: scheme.onErrorContainer)),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    style: redButton,
                    onPressed: () => onCall(EmergencyNumbers.samu),
                    icon: const Icon(Icons.phone),
                    label: const Text('SAMU · ${EmergencyNumbers.samu}', style: TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => onCall(EmergencyNumbers.civilProtection),
                    icon: const Icon(Icons.fire_truck),
                    label: const Text('Protection civile · ${EmergencyNumbers.civilProtection}'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (activeEmergency)
            Card(
              child: ListTile(
                leading: Icon(Icons.campaign, color: scheme.error),
                title: const Text('Alerte en cours'),
                subtitle: const Text('Vos médecins ont été prévenus. Clôturez-la quand vous allez mieux.'),
              ),
            )
          else
            FilledButton.icon(
              style: redButton,
              onPressed: sending ? null : onAlert,
              icon: sending
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.emergency_share),
              label: const Text('Alerter mes médecins'),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: onTransport,
            icon: const Icon(Icons.airport_shuttle),
            label: const Text('Demander un transport programmé'),
          ),
          const SizedBox(height: 16),
          Text('Mes demandes', style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
