import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/calls/call_service.dart';
import '../core/utils/launcher.dart';
import 'ui_helpers.dart';

/// Médecin : un de ses patients est en ligne avec le SAMU. Même écran d'appel que côté patient
/// (sonnerie, chrono, fin d'appel), mis à jour en direct par le serveur.
class SamuWatch extends StatefulWidget {
  const SamuWatch({super.key, required this.call, required this.onClose});

  final SamuCallInfo call;
  final VoidCallback onClose;

  @override
  State<SamuWatch> createState() => _SamuWatchState();
}

class _SamuWatchState extends State<SamuWatch> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
    ..repeat();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  static String _clock(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get _status {
    final c = widget.call;
    if (c.ended) {
      return (c.durationSeconds ?? 0) > 0 ? 'Appel terminé · ${_clock(c.durationSeconds!)}' : 'Appel terminé';
    }
    if (c.connectedAt == null) return 'Appel en cours…';
    return _clock(DateTime.now().difference(c.connectedAt!).inSeconds);
  }

  /// Appel audio intégré (WebRTC) : fonctionne aussi dans le navigateur, contrairement au composeur.
  void _callInApp() {
    final c = widget.call;
    context.read<CallService>().startCall(
          contactId: c.patientId,
          name: c.patientName,
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
    final c = widget.call;
    final ringing = !c.ended && c.connectedAt == null;
    if (ringing && !_pulse.isAnimating) _pulse.repeat();
    if (!ringing && _pulse.isAnimating) _pulse.stop();

    return Material(
      color: const Color(0xFF101418),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: (c.ended ? Colors.white : Colors.red).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(c.ended ? Icons.call_end : Icons.emergency,
                      color: c.ended ? Colors.white70 : Colors.redAccent, size: 18),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      c.ended ? 'Votre patient a raccroché' : 'Votre patient appelle le ${c.label} en ce moment',
                      style: TextStyle(color: c.ended ? Colors.white70 : Colors.redAccent),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: 200,
              height: 200,
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) => Stack(
                  alignment: Alignment.center,
                  children: [
                    if (ringing)
                      for (final offset in const [0.0, 0.5])
                        Builder(builder: (_) {
                          final t = (_pulse.value + offset) % 1.0;
                          return Container(
                            width: 110 + 90 * t,
                            height: 110 + 90 * t,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.red.withValues(alpha: 0.35 * (1 - t)),
                            ),
                          );
                        }),
                    CircleAvatar(
                      radius: 55,
                      backgroundColor: c.ended ? Colors.white24 : Colors.red.shade600,
                      child: const Icon(Icons.local_hospital, size: 52, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(c.patientName, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('→ ${c.label} · ${c.number}',
                style: const TextStyle(color: Colors.white70, fontSize: 17, letterSpacing: 1)),
            const SizedBox(height: 12),
            Text(_status, style: const TextStyle(color: Colors.white, fontSize: 18)),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                runSpacing: 6,
                children: [
                  if (c.bloodGroup != null) _Info(Icons.bloodtype, c.bloodGroup!),
                  if (c.allergies != null && c.allergies!.isNotEmpty)
                    _Info(Icons.warning_amber, 'Allergies : ${c.allergies}'),
                  if (c.phone != null) _Info(Icons.phone, c.phone!),
                  _Info(Icons.place, c.hasLocation ? 'Position GPS reçue' : 'Position en attente'),
                ],
              ),
            ),
            const Spacer(),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 28,
              children: [
                _RoundButton(
                  icon: Icons.call,
                  label: 'Appeler le patient',
                  background: Colors.green.shade600,
                  onPressed: _callInApp,
                ),
                if (c.phone != null && !kIsWeb)
                  _RoundButton(
                    icon: Icons.dialpad,
                    label: 'Téléphone',
                    onPressed: () => _dialPhone(c.phone!),
                  ),
                if (c.hasLocation)
                  _RoundButton(
                    icon: Icons.map,
                    label: 'Carte',
                    onPressed: () => Launcher.openMap(c.latitude!, c.longitude!),
                  ),
                _RoundButton(
                  icon: Icons.close,
                  label: 'Fermer',
                  onPressed: widget.onClose,
                ),
              ],
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white54, size: 16),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.background = Colors.white24,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 64,
          height: 64,
          child: IconButton.filled(
            style: IconButton.styleFrom(backgroundColor: background, foregroundColor: Colors.white),
            tooltip: label,
            onPressed: onPressed,
            icon: Icon(icon, size: 28),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}
