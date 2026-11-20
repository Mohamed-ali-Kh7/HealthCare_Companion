import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/calls/call_service.dart';
import '../core/utils/launcher.dart';
import '../models/ambulance_request.dart';
import '../services/ambulance_service.dart';
import 'ui_helpers.dart';

/// Alerte plein écran affichée au médecin quand un de ses patients déclenche une urgence.
/// Placée dans CallOverlay : visible quel que soit l'écran ouvert.
class EmergencyAlert extends StatefulWidget {
  const EmergencyAlert({super.key, required this.request, required this.onDismiss});

  final AmbulanceRequest request;
  final VoidCallback onDismiss;

  @override
  State<EmergencyAlert> createState() => _EmergencyAlertState();
}

class _EmergencyAlertState extends State<EmergencyAlert> with SingleTickerProviderStateMixin {
  late final AnimationController _blink = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
    ..repeat(reverse: true);
  bool _taking = false;

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  Future<void> _takeCharge() async {
    setState(() => _taking = true);
    final ok = await runWithFeedback(
      context,
      () => context.read<AmbulanceService>().takeCharge(widget.request.id),
      successMessage: 'Urgence prise en charge',
    );
    if (!mounted) return;
    setState(() => _taking = false);
    if (ok) widget.onDismiss();
  }

  /// Appel audio intégré (WebRTC) : fonctionne aussi dans le navigateur, contrairement au composeur.
  void _callInApp() {
    final p = widget.request.patient;
    context.read<CallService>().startCall(
          contactId: p.id,
          name: p.fullName,
          subtitle: 'Urgence en cours',
          video: false,
        );
  }

  Future<void> _dialPhone(String phone) async {
    if (!await Launcher.call(phone) && mounted) {
      showSnack(context, 'Cet appareil ne peut pas appeler : composez le $phone', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final p = r.patient;
    const white = TextStyle(color: Colors.white);

    return Material(
      color: const Color(0xF2B71C1C),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FadeTransition(
                    opacity: Tween(begin: 0.35, end: 1.0).animate(_blink),
                    child: const Icon(Icons.emergency, color: Colors.white, size: 72),
                  ),
                  const SizedBox(height: 8),
                  const Text('URGENCE PATIENT',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  const SizedBox(height: 16),
                  Text(p.fullName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  Card(
                    color: Colors.white.withValues(alpha: 0.12),
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Line(Icons.report, 'Motif', r.reason ?? 'Non précisé'),
                          if (p.phone != null) _Line(Icons.phone, 'Téléphone', p.phone!),
                          if (p.bloodGroup != null) _Line(Icons.bloodtype, 'Groupe sanguin', p.bloodGroup!),
                          if (p.allergies != null && p.allergies!.isNotEmpty)
                            _Line(Icons.warning_amber, 'Allergies', p.allergies!),
                          _Line(Icons.place, 'Position', r.hasLocation ? 'Disponible (GPS)' : 'Indisponible'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red.shade900,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: _taking ? null : _takeCharge,
                    icon: _taking
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.medical_services),
                    label: const Text('Prendre en charge', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: _outlined,
                          onPressed: _callInApp,
                          icon: const Icon(Icons.call),
                          label: const Text('Appeler'),
                        ),
                      ),
                      if (p.phone != null && !kIsWeb) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: _outlined,
                            onPressed: () => _dialPhone(p.phone!),
                            icon: const Icon(Icons.dialpad),
                            label: const Text('Téléphone'),
                          ),
                        ),
                      ],
                      if (r.hasLocation) const SizedBox(width: 8),
                      if (r.hasLocation)
                        Expanded(
                          child: OutlinedButton.icon(
                            style: _outlined,
                            onPressed: () => Launcher.openMap(r.latitude!, r.longitude!),
                            icon: const Icon(Icons.map),
                            label: const Text('Carte'),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: widget.onDismiss,
                    child: const Text('Plus tard (voir dans Urgences)', style: white),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static final _outlined = OutlinedButton.styleFrom(
    foregroundColor: Colors.white,
    side: const BorderSide(color: Colors.white70),
    minimumSize: const Size.fromHeight(48),
  );
}

class _Line extends StatelessWidget {
  const _Line(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(TextSpan(children: [
              TextSpan(text: '$label : ', style: const TextStyle(color: Colors.white70)),
              TextSpan(text: value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ])),
          ),
        ],
      ),
    );
  }
}
