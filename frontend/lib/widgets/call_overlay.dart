import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';

import '../core/calls/call_service.dart';
import '../core/utils/formatters.dart';
import '../models/ambulance_request.dart';
import '../models/order.dart';
import '../models/invoice.dart';
import 'emergency_alert.dart';
import 'samu_watch.dart';
import 'ui_helpers.dart';

/// Couche placée au-dessus de toute l'application (MaterialApp.builder) :
/// un appel entrant ou en cours s'affiche quel que soit l'écran ouvert.
class CallOverlay extends StatefulWidget {
  const CallOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<CallOverlay> createState() => _CallOverlayState();
}

class _CallOverlayState extends State<CallOverlay> {
  StreamSubscription<String>? _notices;
  StreamSubscription<AmbulanceRequest>? _emergencySub;

  /// Urgences reçues en direct, affichées une par une (la plus ancienne d'abord).
  final List<AmbulanceRequest> _emergencies = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final calls = context.read<CallService>();
    _notices ??= calls.notices.listen((message) {
      if (mounted) showSnack(context, message);
    });
    _emergencySub ??= calls.emergencies.listen((request) {
      if (!mounted || _emergencies.any((e) => e.id == request.id)) return;
      setState(() => _emergencies.add(request));
    });
    _transportSub ??= calls.transportRequests.listen((r) {
      final when = r.scheduledAt == null ? '' : ' pour le ${Fmt.dateTime(r.scheduledAt!)}';
      _showInfo(Icons.airport_shuttle,
          'Nouvelle demande de transport de ${r.patient.fullName}$when.\nÀ valider dans l\'onglet Urgences.');
    });
    _doctorStatusSub ??= calls.doctorStatus.listen((s) {
      final until = s.until == null ? '' : ' jusqu\'au ${Fmt.date(s.until)}';
      _showInfo(
        s.away ? Icons.event_busy : Icons.event_available,
        s.away
            ? '${s.doctorName} est absent$until.${s.message == null ? '' : '\n« ${s.message} »'}\n'
                'Dans votre conversation, « Transférer à l\'assistant » pour une réponse immédiate.'
            : '${s.doctorName} est de nouveau disponible.',
      );
    });
    _orderSub ??= calls.orderUpdates.listen((o) {
      final med = '${o.quantity} × ${o.medicine.name} ${o.medicine.strength}';
      final kind = o.isDelivery ? 'commande' : 'réservation';
      final note = o.pharmacistNote == null ? '' : '\n« ${o.pharmacistNote} »';
      final text = switch (o.status) {
        // Côté pharmacien
        OrderStatus.pending => 'Nouvelle $kind de ${o.patient.fullName} : $med.\nÀ traiter dans l\'onglet Commandes.',
        OrderStatus.cancelled => '${o.patient.fullName} a annulé sa $kind ($med).',
        // Côté patient
        OrderStatus.confirmed => o.isDelivery
            ? '${o.pharmacy.name} a confirmé votre commande ($med) : livraison en cours.$note'
            : 'Votre réservation est prête : $med chez ${o.pharmacy.name}.$note',
        OrderStatus.rejected => '${o.pharmacy.name} a refusé votre $kind ($med).$note',
        OrderStatus.completed => o.isDelivery ? 'Commande livrée : $med.' : 'Retrait confirmé : $med.',
      };
      _showInfo(o.type.icon, text);
    });
    // Ambulance conventionnée : même message pour le patient, son médecin et la société
    _missionSub ??= calls.missionUpdates.listen((r) {
      final m = r.mission;
      if (m == null) return;
      final when = r.scheduledAt == null ? '' : ' du ${Fmt.dateTime(r.scheduledAt!)}';
      final vehicle = m.vehicle == null ? '' : ' · ${m.vehicle!.plate}';
      final note = m.note == null ? '' : '\n« ${m.note} »';
      // Annulé par le patient, ou clôturé avant que la société ne l'ait pris en charge
      if (r.status == AmbulanceRequestStatus.cancelled ||
          (r.status == AmbulanceRequestStatus.closed && m.status != MissionStatus.arrived)) {
        final what = r.status == AmbulanceRequestStatus.cancelled ? 'annulé par le patient' : 'clôturé';
        _showInfo(Icons.cancel_outlined, 'Transport$when de ${r.patient.fullName} $what (${m.company.name}).');
        return;
      }
      _showInfo(m.status.icon,
          'Transport$when de ${r.patient.fullName}\n${m.status.label} : ${m.company.name}$vehicle$note');
    });
    _invoiceSub ??= calls.invoiceUpdates.listen((i) {
      final text = !i.isPaid
          ? 'Nouvelle facture de ${i.issuer.name} : ${Fmt.price(i.patientDue)} à payer.\nMenu 🧾 Mes factures.'
          : i.paymentMethod == 'CASH'
              ? 'Paiement au cabinet enregistré : facture ${i.number} (${Fmt.price(i.patientDue)}).'
              : '${i.patient.fullName} a payé la facture ${i.number} en ligne : ${Fmt.price(i.patientDue)}.';
      _showInfo(Icons.receipt_long, text);
    });
  }

  StreamSubscription<AmbulanceRequest>? _transportSub;
  StreamSubscription<DoctorStatus>? _doctorStatusSub;
  StreamSubscription<MedicineOrder>? _orderSub;
  StreamSubscription<Invoice>? _invoiceSub;
  StreamSubscription<AmbulanceRequest>? _missionSub;

  /// Bandeau d'information (nouvelle demande, commande mise à jour...), visible sur tous les écrans.
  void _showInfo(IconData icon, String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        duration: const Duration(seconds: 8),
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
          ],
        ),
      ));
  }

  @override
  void dispose() {
    _notices?.cancel();
    _emergencySub?.cancel();
    _transportSub?.cancel();
    _orderSub?.cancel();
    _invoiceSub?.cancel();
    _missionSub?.cancel();
    _doctorStatusSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final call = context.watch<CallService>();
    return Stack(
      children: [
        widget.child,
        if (_emergencies.isNotEmpty)
          Positioned.fill(
            child: Overlay.wrap(
              child: EmergencyAlert(
                key: ValueKey(_emergencies.first.id),
                request: _emergencies.first,
                onDismiss: () => setState(() => _emergencies.removeAt(0)),
              ),
            ),
          ),
        if (call.samuCall != null)
          Positioned.fill(
            child: Overlay.wrap(
              child: SamuWatch(
                key: ValueKey('samu-${call.samuCall!.patientUserId}'),
                call: call.samuCall!,
                onClose: call.dismissSamuCall,
              ),
            ),
          ),
        // Overlay propre : cette couche est au-dessus du Navigator, dont l'Overlay n'est pas accessible ici
        // (les infobulles des boutons en ont besoin)
        if (call.phase == CallPhase.incoming)
          Positioned.fill(child: Overlay.wrap(child: _IncomingCall(call: call)))
        else if (call.phase != CallPhase.idle)
          Positioned.fill(child: Overlay.wrap(child: _OngoingCall(call: call))),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final parts = name.replaceFirst('Dr ', '').split(' ').where((p) => p.isNotEmpty).toList();
    final initials = parts.take(2).map((p) => p[0].toUpperCase()).join();
    return CircleAvatar(
      radius: 52,
      backgroundColor: Colors.white24,
      child: Text(initials, style: const TextStyle(fontSize: 36, color: Colors.white)),
    );
  }
}

/// Bouton rond des écrans d'appel.
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.background = Colors.white24,
    this.size = 60,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color background;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: IconButton.filled(
            style: IconButton.styleFrom(backgroundColor: background, foregroundColor: Colors.white),
            tooltip: label,
            onPressed: onPressed,
            icon: Icon(icon, size: size * 0.45),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}

class _IncomingCall extends StatelessWidget {
  const _IncomingCall({required this.call});

  final CallService call;

  @override
  Widget build(BuildContext context) {
    final peer = call.peer!;
    return Material(
      color: const Color(0xF0101418),
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            const Icon(Icons.ring_volume, color: Colors.white70, size: 28),
            const SizedBox(height: 8),
            Text(call.video ? 'Appel vidéo entrant' : 'Appel audio entrant',
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 24),
            _Avatar(name: peer.name),
            const SizedBox(height: 16),
            Text(peer.name, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600)),
            if (peer.subtitle != null) Text(peer.subtitle!, style: const TextStyle(color: Colors.white70)),
            const Spacer(flex: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _RoundButton(
                  icon: Icons.call_end,
                  label: 'Refuser',
                  background: Colors.red.shade600,
                  size: 68,
                  onPressed: call.reject,
                ),
                _RoundButton(
                  icon: call.video ? Icons.videocam : Icons.call,
                  label: 'Accepter',
                  background: Colors.green.shade600,
                  size: 68,
                  onPressed: call.accept,
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

class _OngoingCall extends StatefulWidget {
  const _OngoingCall({required this.call});

  final CallService call;

  @override
  State<_OngoingCall> createState() => _OngoingCallState();
}

class _OngoingCallState extends State<_OngoingCall> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.call.phase == CallPhase.active) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String get _status {
    final call = widget.call;
    switch (call.phase) {
      case CallPhase.outgoing:
        return 'Appel en cours…';
      case CallPhase.connecting:
        return 'Connexion…';
      case CallPhase.active:
        final d = DateTime.now().difference(call.connectedAt ?? DateTime.now());
        final minutes = d.inMinutes.toString().padLeft(2, '0');
        final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
        return '$minutes:$seconds';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final call = widget.call;
    final peer = call.peer;
    final showRemoteVideo = call.video && call.phase == CallPhase.active;
    final showLocalVideo = call.video && !call.cameraOff;

    return Material(
      color: const Color(0xFF101418),
      child: Stack(
        children: [
          // L'audio distant est joué par flutter_webrtc lui-même (aucune vue nécessaire pour un appel audio)
          if (showRemoteVideo)
            Positioned.fill(
              child: RTCVideoView(call.remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
            ),
          // Positioned.fill : sans contrainte serrée, la colonne se réduit à son contenu et se colle à gauche
          Positioned.fill(
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 24),
                  if (!showRemoteVideo) ...[
                    const SizedBox(height: 40),
                    _Avatar(name: peer?.name ?? ''),
                    const SizedBox(height: 16),
                  ],
                  Text(peer?.name ?? '',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          shadows: [Shadow(blurRadius: 6)])),
                  const SizedBox(height: 4),
                  Text(_status, style: const TextStyle(color: Colors.white70, shadows: [Shadow(blurRadius: 6)])),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 32),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 20,
                      runSpacing: 12,
                      children: [
                        _RoundButton(
                          icon: call.micMuted ? Icons.mic_off : Icons.mic,
                          label: call.micMuted ? 'Micro coupé' : 'Micro',
                          onPressed: call.toggleMic,
                        ),
                        if (call.video)
                          _RoundButton(
                            icon: call.cameraOff ? Icons.videocam_off : Icons.videocam,
                            label: call.cameraOff ? 'Caméra coupée' : 'Caméra',
                            onPressed: call.toggleCamera,
                          ),
                        if (call.video && !kIsWeb)
                          _RoundButton(
                            icon: Icons.cameraswitch,
                            label: 'Retourner',
                            onPressed: call.switchCamera,
                          ),
                        _RoundButton(
                          icon: Icons.call_end,
                          label: 'Raccrocher',
                          background: Colors.red.shade600,
                          onPressed: call.hangUp,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (showLocalVideo)
            Positioned(
              right: 16,
              top: MediaQuery.paddingOf(context).top + 16,
              width: 110,
              height: 160,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ColoredBox(
                  color: Colors.black,
                  child: RTCVideoView(call.localRenderer,
                      mirror: true, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
