import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/calls/call_service.dart';
import '../../core/utils/launcher.dart';
import '../../core/utils/location_helper.dart';
import '../../services/ambulance_service.dart';
import '../../widgets/ui_helpers.dart';

/// Écran d'appel d'urgence (SAMU 190, Protection civile 198), même style que les appels de l'application.
/// Sur un téléphone, le composeur du système est ouvert : c'est lui qui passe le vrai appel.
/// Sans téléphonie (navigateur, PC), l'écran sert de simulation et le signale clairement.
/// Renvoie true (via Navigator.pop) si une alerte a été envoyée aux médecins.
class EmergencyCallScreen extends StatefulWidget {
  const EmergencyCallScreen({super.key, required this.number, required this.label});

  final String number;
  final String label;

  @override
  State<EmergencyCallScreen> createState() => _EmergencyCallScreenState();
}

enum _Phase { dialing, connected }

class _EmergencyCallScreenState extends State<EmergencyCallScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
    ..repeat();
  Timer? _ticker;
  Timer? _connectDelay;
  _Phase _phase = _Phase.dialing;
  DateTime? _connectedAt;
  bool _simulated = false;
  bool _speaker = false;
  bool _muted = false;
  bool _alerting = false;
  bool _alertSent = false;

  /// Relais en direct vers les médecins du patient (lu ici : inutilisable dans dispose()).
  late final CallService _live = context.read<CallService>();

  @override
  void initState() {
    super.initState();
    _live.samuStart(number: widget.number, label: widget.label);
    _shareLocation();
    _startCall();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _phase == _Phase.connected) setState(() {});
    });
  }

  Future<void> _startCall() async {
    final launched = await Launcher.call(widget.number);
    if (!mounted) return;
    setState(() => _simulated = !launched);
    // Sonnerie de quelques secondes avant la mise en relation
    _connectDelay = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.connected;
        _connectedAt = DateTime.now();
      });
      _pulse.stop();
      _live.samuUpdate(connected: true);
    });
  }

  /// Position envoyée aux médecins dès qu'elle est connue (sans GPS : rien d'inventé).
  Future<void> _shareLocation() async {
    final position = await LocationHelper.current();
    if (!mounted || position.isFallback) return;
    _live.samuUpdate(
      connected: _phase == _Phase.connected,
      latitude: position.lat,
      longitude: position.lng,
    );
  }

  @override
  void dispose() {
    _live.samuEnd();
    _ticker?.cancel();
    _connectDelay?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  String get _status {
    if (_phase == _Phase.dialing) return 'Appel en cours…';
    final d = DateTime.now().difference(_connectedAt ?? DateTime.now());
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _alertDoctors() async {
    final service = context.read<AmbulanceService>();
    setState(() => _alerting = true);
    // Pas de position inventée : sans GPS, on n'envoie pas de coordonnées
    final position = await LocationHelper.current();
    if (!mounted) return;
    final sent = await runWithFeedback(
      context,
      () => service.sendEmergency(
        lat: position.isFallback ? null : position.lat,
        lng: position.isFallback ? null : position.lng,
        reason: 'Appel ${widget.label} (${widget.number}) en cours',
      ),
      successMessage: position.isFallback
          ? 'Alerte envoyée à vos médecins (position indisponible)'
          : 'Alerte envoyée à vos médecins avec votre position',
    );
    if (!mounted) return;
    setState(() {
      _alerting = false;
      _alertSent = _alertSent || sent;
    });
  }

  void _hangUp() => Navigator.of(context).pop(_alertSent);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _hangUp();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF101418),
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 16),
              if (_simulated)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Simulation : cet appareil ne peut pas appeler. '
                      'Composez le ${widget.number} depuis un téléphone.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.orangeAccent, fontSize: 13),
                    ),
                  ),
                ),
              const Spacer(),
              _PulsingAvatar(animation: _pulse, active: _phase == _Phase.dialing),
              const SizedBox(height: 24),
              Text(widget.label,
                  style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(widget.number, style: const TextStyle(color: Colors.white70, fontSize: 18, letterSpacing: 2)),
              const SizedBox(height: 12),
              Text(_status, style: const TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 16),
              _LiveBadge(ack: context.watch<CallService>().samuAck),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: _alertSent
                    ? const ListTile(
                        leading: Icon(Icons.check_circle, color: Colors.greenAccent),
                        title: Text('Vos médecins ont été prévenus', style: TextStyle(color: Colors.white)),
                      )
                    : OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white38),
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: _alerting ? null : _alertDoctors,
                        icon: _alerting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.emergency_share),
                        label: const Text('Alerter aussi mes médecins'),
                      ),
              ),
              const SizedBox(height: 32),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 28,
                children: [
                  _RoundButton(
                    icon: _muted ? Icons.mic_off : Icons.mic,
                    label: _muted ? 'Micro coupé' : 'Micro',
                    onPressed: () => setState(() => _muted = !_muted),
                  ),
                  _RoundButton(
                    icon: _speaker ? Icons.volume_up : Icons.volume_down,
                    label: 'Haut-parleur',
                    selected: _speaker,
                    onPressed: () => setState(() => _speaker = !_speaker),
                  ),
                  _RoundButton(
                    icon: Icons.call_end,
                    label: 'Raccrocher',
                    background: Colors.red.shade600,
                    onPressed: _hangUp,
                  ),
                ],
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}

/// Indique au patient si ses médecins voient l'appel en direct.
class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.ack});

  final ({int doctors, int online})? ack;

  @override
  Widget build(BuildContext context) {
    final a = ack;
    if (a == null || a.doctors == 0) return const SizedBox.shrink();
    final live = a.online > 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(live ? Icons.visibility : Icons.visibility_off,
            size: 16, color: live ? Colors.greenAccent : Colors.white54),
        const SizedBox(width: 6),
        Text(
          live ? 'Vos médecins suivent cet appel en direct' : 'Vos médecins ne sont pas connectés',
          style: TextStyle(color: live ? Colors.greenAccent : Colors.white54, fontSize: 13),
        ),
      ],
    );
  }
}

/// Avatar rouge avec des ondes pendant la sonnerie.
class _PulsingAvatar extends StatelessWidget {
  const _PulsingAvatar({required this.animation, required this.active});

  final Animation<double> animation;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) => Stack(
          alignment: Alignment.center,
          children: [
            if (active)
              for (final offset in const [0.0, 0.5])
                Builder(builder: (_) {
                  final t = (animation.value + offset) % 1.0;
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
              backgroundColor: Colors.red.shade600,
              child: const Icon(Icons.local_hospital, size: 52, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.background = Colors.white24,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color background;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 64,
          height: 64,
          child: IconButton.filled(
            style: IconButton.styleFrom(
              backgroundColor: selected ? Colors.white : background,
              foregroundColor: selected ? Colors.black87 : Colors.white,
            ),
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
