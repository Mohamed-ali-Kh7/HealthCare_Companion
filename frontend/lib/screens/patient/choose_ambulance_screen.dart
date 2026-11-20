import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../core/utils/launcher.dart';
import '../../core/utils/location_helper.dart';
import '../../models/ambulance_request.dart';
import '../../models/transport.dart';
import '../../services/transport_service.dart';
import '../../widgets/async_view.dart';
import '../../widgets/ui_helpers.dart';

/// Patient : choix d'une société d'ambulance conventionnée CNAM pour un transport validé par le médecin.
/// Sociétés qui desservent l'adresse de prise en charge, les plus proches d'abord.
class ChooseAmbulanceScreen extends StatefulWidget {
  const ChooseAmbulanceScreen({super.key, required this.request});

  final AmbulanceRequest request;

  @override
  State<ChooseAmbulanceScreen> createState() => _ChooseAmbulanceScreenState();
}

class _ChooseAmbulanceScreenState extends State<ChooseAmbulanceScreen> {
  int? _sendingTo;

  Future<List<AmbulanceCompany>> _load() async {
    final r = widget.request;
    // Point de prise en charge du transport ; sinon la position actuelle (ou Tunis par défaut)
    final point = r.hasLocation ? (lat: r.latitude!, lng: r.longitude!) : await _currentPosition();
    if (!mounted) return const [];
    return context.read<TransportService>().nearby(point.lat, point.lng);
  }

  Future<({double lat, double lng})> _currentPosition() async {
    final p = await LocationHelper.current();
    return (lat: p.lat, lng: p.lng);
  }

  Future<void> _choose(AmbulanceCompany c) async {
    final ok = await confirm(context,
        title: 'Confier le transport à ${c.name} ?',
        message: 'La société reçoit votre demande pour le ${Fmt.dateTime(widget.request.scheduledAt!)} '
            'et vous confirmera le véhicule.',
        confirmLabel: 'Envoyer la demande');
    if (!ok || !mounted) return;
    setState(() => _sendingTo = c.id);
    try {
      final updated = await context.read<TransportService>().chooseCompany(widget.request.id, c.id);
      if (mounted) Navigator.of(context).pop(updated);
    } catch (e) {
      if (mounted) {
        setState(() => _sendingTo = null);
        showSnack(context, errorMessage(e), isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final current = r.mission?.status == MissionStatus.requested ? r.mission!.company.id : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Ambulances conventionnées')),
      body: AsyncView<List<AmbulanceCompany>>(
        load: _load,
        builder: (context, companies, reload) => RefreshableList(
          onRefresh: reload,
          itemCount: companies.length,
          header: Card(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: ListTile(
              leading: const Icon(Icons.airport_shuttle),
              title: Text('Transport du ${Fmt.dateTime(r.scheduledAt!)}'),
              subtitle: Text('${r.address ?? ''}\nSociétés conventionnées CNAM qui desservent cette adresse.'),
              isThreeLine: true,
            ),
          ),
          empty: const EmptyState(
            icon: Icons.airport_shuttle_outlined,
            message: 'Aucune société conventionnée disponible près de cette adresse.\n'
                'Contactez votre médecin ou la CNAM.',
          ),
          itemBuilder: (context, i) {
            final c = companies[i];
            final isCurrent = c.id == current;
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text(c.name, style: Theme.of(context).textTheme.titleMedium)),
                      if (c.distanceKm != null)
                        Chip(
                          visualDensity: VisualDensity.compact,
                          avatar: const Icon(Icons.near_me, size: 16),
                          label: Text('${c.distanceKm!.toStringAsFixed(1)} km'),
                        ),
                    ]),
                    Text('Convention CNAM ${c.conventionNumber}'),
                    Text('${c.address}, ${c.city}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    Text('${c.vehiclesInService ?? 0} véhicule(s) en service'),
                    const SizedBox(height: 4),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.phone, size: 18),
                          label: Text(c.phone),
                          onPressed: () async {
                            if (!await Launcher.call(c.phone) && context.mounted) {
                              showSnack(context, 'Appel impossible sur cet appareil', isError: true);
                            }
                          },
                        ),
                        if (isCurrent)
                          const Chip(avatar: Icon(Icons.hourglass_top, size: 16), label: Text('Demande envoyée'))
                        else
                          FilledButton(
                            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                            onPressed: _sendingTo != null ? null : () => _choose(c),
                            child: Text(_sendingTo == c.id ? 'Envoi…' : 'Choisir'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
