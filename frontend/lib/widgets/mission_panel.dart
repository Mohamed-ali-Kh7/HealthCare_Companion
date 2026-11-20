import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/calls/call_service.dart';
import '../core/utils/formatters.dart';
import '../core/utils/launcher.dart';
import '../models/ambulance_request.dart';
import 'ui_helpers.dart';

/// Suivi d'un transport confié à une société conventionnée : société, véhicule, équipage et frise des étapes.
class MissionPanel extends StatelessWidget {
  const MissionPanel({super.key, required this.mission, this.requestId, this.showContacts = true});

  final TransportMission mission;

  /// Demande de transport : permet d'appeler la société dans l'application.
  final int? requestId;

  /// Boutons pour appeler la société et le chauffeur (patient, médecin).
  final bool showContacts;

  @override
  Widget build(BuildContext context) {
    final m = mission;
    final scheme = Theme.of(context).colorScheme;
    final muted = TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5);
    final reached = MissionStatus.journey.indexOf(m.status);

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: m.status.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: m.status.color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(m.status.icon, color: m.status.color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(m.status.label, style: TextStyle(fontWeight: FontWeight.w700, color: m.status.color)),
            ),
            if (m.updatedAt != null) Text(Fmt.time(m.updatedAt!), style: muted),
          ]),
          const SizedBox(height: 6),
          Text('🚑 ${m.company.name}', style: const TextStyle(fontWeight: FontWeight.w600)),
          if (m.company.conventionNumber != null) Text('Convention CNAM ${m.company.conventionNumber}', style: muted),
          if (m.vehicle != null)
            Text('${m.vehicle!.typeLabel} · ${m.vehicle!.plate}'
                '${m.vehicle!.driverName == null ? '' : ' · ${m.vehicle!.driverName}'}'),
          if (m.note != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('« ${m.note} »', style: const TextStyle(fontStyle: FontStyle.italic)),
            ),
          if (reached >= 0) ...[
            const SizedBox(height: 10),
            _Journey(reached: reached),
          ],
          if (showContacts && m.status != MissionStatus.refused && m.status != MissionStatus.arrived) ...[
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: [
              // Appel dans l'application (fonctionne aussi dans le navigateur)
              if (requestId != null)
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.call, size: 18),
                  label: const Text('Appeler la société'),
                  onPressed: () => context.read<CallService>().startCall(
                        contactId: 0,
                        missionId: requestId,
                        name: m.company.name,
                        subtitle: 'Ambulance conventionnée',
                        video: false,
                      ),
                ),
              // Numéro de téléphone : appel classique depuis un téléphone
              TextButton.icon(
                icon: const Icon(Icons.phone, size: 18),
                label: Text(m.company.phone),
                onPressed: () => _call(context, m.company.phone),
              ),
              if (m.vehicle?.driverPhone != null)
                TextButton.icon(
                  icon: const Icon(Icons.person_pin_circle_outlined, size: 18),
                  label: Text('Chauffeur ${m.vehicle!.driverPhone}'),
                  onPressed: () => _call(context, m.vehicle!.driverPhone!),
                ),
            ]),
          ],
        ],
      ),
    );
  }

  Future<void> _call(BuildContext context, String phone) async {
    if (!await Launcher.call(phone) && context.mounted) {
      showSnack(context, 'Appel impossible sur cet appareil : $phone', isError: true);
    }
  }
}

/// Frise : Accepté → En route → Sur place → À bord → Arrivé.
class _Journey extends StatelessWidget {
  const _Journey({required this.reached});

  final int reached;

  static const _short = ['Accepté', 'En route', 'Sur place', 'À bord', 'Arrivé'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (var k = 0; k < _short.length; k++) ...[
          Expanded(
            child: Column(children: [
              CircleAvatar(
                radius: 11,
                backgroundColor: k <= reached ? scheme.primary : scheme.surfaceContainerHighest,
                child: Icon(k < reached ? Icons.check : MissionStatus.journey[k].icon,
                    size: 13, color: k <= reached ? scheme.onPrimary : scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 3),
              Text(_short[k],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: k == reached ? FontWeight.w700 : null,
                      color: k <= reached ? scheme.onSurface : scheme.onSurfaceVariant)),
            ]),
          ),
        ],
      ],
    );
  }
}
