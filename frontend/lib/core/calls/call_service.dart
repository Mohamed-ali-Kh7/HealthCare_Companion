import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../models/ambulance_request.dart';
import '../../models/order.dart';
import '../../models/invoice.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../config/app_config.dart';
import '../storage/token_storage.dart';

enum CallPhase {
  idle,

  /// L'utilisateur appelle, l'autre ne répond pas encore.
  outgoing,

  /// Un appel sonne chez l'utilisateur.
  incoming,

  /// Décroché : établissement de la connexion audio/vidéo.
  connecting,
  active,
}

/// L'autre participant de l'appel. [contactId] : id à utiliser pour ouvrir la conversation.
class CallPeer {
  const CallPeer({required this.contactId, required this.name, this.subtitle});

  final int contactId;
  final String name;
  final String? subtitle;
}

/// Médecin : appel SAMU passé en ce moment par un de ses patients (suivi en direct).
class SamuCallInfo {
  SamuCallInfo({
    required this.patientUserId,
    required this.patientId,
    required this.patientName,
    required this.number,
    required this.label,
    this.phone,
    this.bloodGroup,
    this.allergies,
    this.latitude,
    this.longitude,
    this.connectedAt,
  });

  final int patientUserId;

  /// Id du profil patient : contactId de l'appel audio intégré.
  final int patientId;
  final String patientName;
  final String number;
  final String label;
  final String? phone;
  final String? bloodGroup;
  final String? allergies;
  final double? latitude;
  final double? longitude;

  /// Heure locale de mise en relation (null : ça sonne encore).
  final DateTime? connectedAt;

  /// Renseignés quand le patient a raccroché.
  bool ended = false;
  int? durationSeconds;

  bool get hasLocation => latitude != null && longitude != null;
}

/// Patient : un de ses médecins passe absent ou redevient disponible.
class DoctorStatus {
  const DoctorStatus({required this.doctorId, required this.doctorName, required this.away, this.message, this.until});

  final int doctorId;
  final String doctorName;
  final bool away;
  final String? message;
  final DateTime? until;
}

/// Appels audio/vidéo patient - médecin (WebRTC).
///
/// - Signalisation par WebSocket (/ws/calls) : connexion ouverte tant qu'un patient ou un médecin est connecté,
///   pour recevoir les appels sur n'importe quel écran ; reconnexion automatique.
/// - L'audio et la vidéo circulent directement entre les deux appareils (pair à pair), pas par le serveur.
class CallService extends ChangeNotifier {
  CallService(this._tokenStorage);

  final TokenStorage _tokenStorage;

  // --- Connexion de signalisation ---
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  bool _wanted = false;
  Timer? _reconnectTimer;
  int _retries = 0;
  List<Map<String, dynamic>> _iceServers = const [
    {
      'urls': ['stun:stun.l.google.com:19302']
    },
  ];

  // --- Appel en cours ---
  CallPhase _phase = CallPhase.idle;
  String? _callId;
  bool _video = false;
  CallPeer? _peer;
  DateTime? _connectedAt;
  bool _cancelWhenRinging = false;
  bool _micMuted = false;
  bool _cameraOff = false;

  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  final List<RTCIceCandidate> _pendingCandidates = [];
  bool _remoteDescriptionSet = false;
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  Future<void>? _renderersReady;

  final _notices = StreamController<String>.broadcast();
  final _emergencies = StreamController<AmbulanceRequest>.broadcast();
  final _transportRequests = StreamController<AmbulanceRequest>.broadcast();
  final _orderUpdates = StreamController<MedicineOrder>.broadcast();
  final _invoiceUpdates = StreamController<Invoice>.broadcast();
  final _missionUpdates = StreamController<AmbulanceRequest>.broadcast();
  final _doctorStatus = StreamController<DoctorStatus>.broadcast();

  CallPhase get phase => _phase;
  bool get video => _video;
  CallPeer? get peer => _peer;
  DateTime? get connectedAt => _connectedAt;
  bool get micMuted => _micMuted;
  bool get cameraOff => _cameraOff;
  bool get isBusy => _phase != CallPhase.idle;
  bool get isConnected => _channel != null;

  /// Messages à afficher (appel refusé, pas de réponse, erreur...).
  Stream<String> get notices => _notices.stream;

  /// Médecin : urgence déclenchée en direct par un de ses patients.
  Stream<AmbulanceRequest> get emergencies => _emergencies.stream;

  /// Médecin : transport programmé qu'un patient lui demande de valider.
  Stream<AmbulanceRequest> get transportRequests => _transportRequests.stream;

  /// Commande de médicament créée (→ pharmacien) ou mise à jour (→ patient / pharmacien).
  Stream<MedicineOrder> get orderUpdates => _orderUpdates.stream;

  /// Facture émise (→ patient) ou réglée (→ médecin).
  Stream<Invoice> get invoiceUpdates => _invoiceUpdates.stream;

  /// Transport en ambulance conventionnée : demande, acceptation, étapes du trajet (patient, médecin, société).
  Stream<AmbulanceRequest> get missionUpdates => _missionUpdates.stream;

  /// Patient : disponibilité de ses médecins (absent / de retour).
  Stream<DoctorStatus> get doctorStatus => _doctorStatus.stream;

  // ---------------------------------------------------------------- Appel SAMU suivi en direct

  SamuCallInfo? _samuCall;
  ({int doctors, int online})? _samuAck;
  Timer? _samuDismissTimer;

  /// Médecin : appel SAMU en cours chez un patient (affiché par CallOverlay).
  SamuCallInfo? get samuCall => _samuCall;

  /// Patient : nombre de médecins (et de fenêtres connectées) qui voient son appel SAMU.
  ({int doctors, int online})? get samuAck => _samuAck;

  /// Patient : début de l'appel SAMU, montré en direct à ses médecins.
  void samuStart({required String number, required String label}) {
    _samuAck = null;
    _send({'type': 'samu_start', 'number': number, 'label': label});
  }

  /// Patient : mise en relation et/ou position GPS.
  void samuUpdate({bool connected = false, double? latitude, double? longitude}) {
    _send({
      'type': 'samu_update',
      'connected': connected,
      'latitude': latitude,
      'longitude': longitude,
    });
  }

  /// Patient : appel SAMU raccroché.
  void samuEnd() {
    _samuAck = null;
    _send({'type': 'samu_end'});
  }

  /// Médecin : ferme l'écran de suivi.
  void dismissSamuCall() {
    _samuDismissTimer?.cancel();
    _samuCall = null;
    notifyListeners();
  }

  void _onSamuCall(Map<String, dynamic> msg) {
    final patient = msg['patient'] as Map<String, dynamic>;
    final id = (msg['patientUserId'] as num).toInt();
    final connected = msg['connected'] as bool? ?? false;
    final previous = _samuCall?.patientUserId == id && !_samuCall!.ended ? _samuCall : null;
    _samuDismissTimer?.cancel();
    _samuCall = SamuCallInfo(
      patientUserId: id,
      patientId: (patient['id'] as num).toInt(),
      patientName: patient['name'] as String? ?? 'Patient',
      phone: patient['phone'] as String?,
      bloodGroup: patient['bloodGroup'] as String?,
      allergies: patient['allergies'] as String?,
      number: msg['number'] as String? ?? '190',
      label: msg['label'] as String? ?? 'SAMU',
      latitude: (msg['latitude'] as num?)?.toDouble(),
      longitude: (msg['longitude'] as num?)?.toDouble(),
      // Le chrono reste stable entre deux mises à jour du même appel
      connectedAt: !connected
          ? null
          : previous?.connectedAt ??
              DateTime.now().subtract(Duration(seconds: (msg['elapsedSeconds'] as num? ?? 0).toInt())),
    );
    notifyListeners();
  }

  void _onSamuEnded(Map<String, dynamic> msg) {
    final call = _samuCall;
    if (call == null || call.patientUserId != (msg['patientUserId'] as num).toInt()) return;
    call
      ..ended = true
      ..durationSeconds = (msg['durationSeconds'] as num?)?.toInt();
    notifyListeners();
    // L'écran affiche « Appel terminé » quelques secondes puis se ferme
    _samuDismissTimer?.cancel();
    _samuDismissTimer = Timer(const Duration(seconds: 8), () {
      if (identical(_samuCall, call)) dismissSamuCall();
    });
  }

  // ---------------------------------------------------------------- Session

  /// Appelé à chaque changement de session : connecté seulement pour un patient ou un médecin.
  void onAuthChanged(AuthStatus status, UserRole? role) {
    final shouldConnect = status == AuthStatus.authenticated &&
        // Pharmacien : uniquement pour les notifications de commandes
        (role == UserRole.patient || role == UserRole.doctor || role == UserRole.pharmacist ||
            role == UserRole.ambulanceCompany);
    if (shouldConnect && !_wanted) {
      _wanted = true;
      _retries = 0;
      // Hors du build en cours (appelé depuis un ProxyProvider)
      scheduleMicrotask(_connect);
    } else if (!shouldConnect && _wanted) {
      _wanted = false;
      scheduleMicrotask(_disconnect);
    }
  }

  Future<void> _connect() async {
    if (!_wanted || _channel != null) return;
    final token = await _tokenStorage.read();
    if (token == null || !_wanted) return;

    final api = Uri.parse(AppConfig.apiBaseUrl);
    final uri = api.replace(
      scheme: api.scheme == 'https' ? 'wss' : 'ws',
      path: '/ws/calls',
      queryParameters: {'token': token},
    );
    final channel = WebSocketChannel.connect(uri);
    try {
      await channel.ready;
    } catch (e) {
      debugPrint('Appels : connexion impossible ($e)');
      _scheduleReconnect();
      return;
    }
    if (!_wanted) {
      channel.sink.close();
      return;
    }
    _channel = channel;
    _retries = 0;
    _subscription = channel.stream.listen(
      _onMessage,
      onDone: _onConnectionLost,
      onError: (_) => _onConnectionLost(),
      cancelOnError: true,
    );
    notifyListeners();
  }

  void _onConnectionLost() {
    _subscription?.cancel();
    _subscription = null;
    _channel = null;
    if (_phase != CallPhase.idle) {
      _endLocally('Connexion perdue');
    }
    notifyListeners();
    _scheduleReconnect();
  }

  /// Reconnexion progressive : 2 s, 4 s, 8 s... jusqu'à 30 s.
  void _scheduleReconnect() {
    if (!_wanted) return;
    _reconnectTimer?.cancel();
    final seconds = (2 << _retries.clamp(0, 4)).clamp(2, 30);
    _retries++;
    _reconnectTimer = Timer(Duration(seconds: seconds), _connect);
  }

  Future<void> _disconnect() async {
    _reconnectTimer?.cancel();
    if (_phase != CallPhase.idle) {
      hangUp();
    }
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------- Actions

  /// [missionId] : appel lié à un transport en ambulance conventionnée (patient ↔ société) au lieu d'un contact
  /// de soin ; [contactId] est alors ignoré.
  Future<void> startCall(
      {required int contactId, required String name, String? subtitle, required bool video, int? missionId}) async {
    if (_phase != CallPhase.idle) return;
    if (_channel == null) {
      _notices.add('Appels indisponibles : connexion au serveur en cours, réessayez.');
      _connect();
      return;
    }
    _phase = CallPhase.outgoing;
    _video = video;
    _peer = CallPeer(contactId: contactId, name: name, subtitle: subtitle);
    notifyListeners();
    if (!await _openMedia()) return;
    _send({
      'type': 'invite',
      if (missionId != null) 'missionId': missionId else 'contactId': contactId,
      'video': video,
    });
  }

  Future<void> accept() async {
    if (_phase != CallPhase.incoming || _callId == null) return;
    _phase = CallPhase.connecting;
    notifyListeners();
    if (!await _openMedia()) {
      _send({'type': 'reject', 'callId': _callId});
      return;
    }
    await _createPeerConnection();
    _send({'type': 'accept', 'callId': _callId});
  }

  void reject() {
    if (_phase != CallPhase.incoming) return;
    _send({'type': 'reject', 'callId': _callId});
    _reset();
  }

  void hangUp() {
    if (_phase == CallPhase.idle) return;
    if (_callId != null) {
      _send({'type': 'hangup', 'callId': _callId});
      _reset();
    } else {
      // Invitation partie mais pas encore confirmée par le serveur : annulée dès la confirmation
      _cancelWhenRinging = true;
      _reset(keepCancelFlag: true);
    }
  }

  void toggleMic() {
    _micMuted = !_micMuted;
    for (final track in _localStream?.getAudioTracks() ?? const <MediaStreamTrack>[]) {
      track.enabled = !_micMuted;
    }
    notifyListeners();
  }

  void toggleCamera() {
    _cameraOff = !_cameraOff;
    for (final track in _localStream?.getVideoTracks() ?? const <MediaStreamTrack>[]) {
      track.enabled = !_cameraOff;
    }
    notifyListeners();
  }

  Future<void> switchCamera() async {
    final tracks = _localStream?.getVideoTracks() ?? const <MediaStreamTrack>[];
    if (tracks.isNotEmpty) await Helper.switchCamera(tracks.first);
  }

  // ---------------------------------------------------------------- Signalisation

  void _onMessage(dynamic raw) {
    final Map<String, dynamic> msg;
    try {
      msg = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    switch (msg['type']) {
      case 'config':
        final servers = msg['iceServers'];
        if (servers is List && servers.isNotEmpty) {
          _iceServers = servers.cast<Map<String, dynamic>>();
        }
      case 'ringing':
        if (_cancelWhenRinging) {
          _cancelWhenRinging = false;
          _send({'type': 'hangup', 'callId': msg['callId']});
          return;
        }
        if (_phase != CallPhase.outgoing) return;
        _callId = msg['callId'] as String;
        notifyListeners();
      case 'incoming':
        if (_phase != CallPhase.idle) return;
        final from = msg['from'] as Map<String, dynamic>;
        _phase = CallPhase.incoming;
        _callId = msg['callId'] as String;
        _video = msg['video'] as bool? ?? false;
        _peer = CallPeer(
          contactId: (from['contactId'] as num).toInt(),
          name: from['name'] as String,
          subtitle: from['subtitle'] as String?,
        );
        notifyListeners();
      case 'accepted':
        if (msg['callId'] != _callId || _phase != CallPhase.outgoing) return;
        _phase = CallPhase.connecting;
        notifyListeners();
        _makeOffer();
      case 'signal':
        if (msg['callId'] != _callId) return;
        _onSignal(msg['data'] as Map<String, dynamic>);
      case 'ended':
        _onEnded(msg);
      case 'samu_ack':
        _samuAck = (
          doctors: (msg['doctors'] as num? ?? 0).toInt(),
          online: (msg['online'] as num? ?? 0).toInt(),
        );
        notifyListeners();
      case 'samu_call':
        _onSamuCall(msg);
      case 'samu_ended':
        _onSamuEnded(msg);
      case 'doctor_status':
        _doctorStatus.add(DoctorStatus(
          doctorId: (msg['doctorId'] as num).toInt(),
          doctorName: msg['doctorName'] as String? ?? 'Votre médecin',
          away: msg['away'] as bool? ?? false,
          message: msg['message'] as String?,
          until: msg['until'] == null ? null : DateTime.tryParse(msg['until'] as String),
        ));
      case 'transport_mission':
        try {
          _missionUpdates.add(AmbulanceRequest.fromJson(msg['request'] as Map<String, dynamic>));
        } catch (e) {
          debugPrint('Mission de transport illisible : $e');
        }
      case 'invoice_update':
        try {
          _invoiceUpdates.add(Invoice.fromJson(msg['invoice'] as Map<String, dynamic>));
        } catch (e) {
          debugPrint('Mise à jour de facture illisible : $e');
        }
      case 'order_update':
        try {
          _orderUpdates.add(MedicineOrder.fromJson(msg['order'] as Map<String, dynamic>));
        } catch (e) {
          debugPrint('Mise à jour de commande illisible : $e');
        }
      case 'transport_request':
        try {
          _transportRequests.add(AmbulanceRequest.fromJson(msg['request'] as Map<String, dynamic>));
        } catch (e) {
          debugPrint('Demande de transport illisible : $e');
        }
      case 'emergency':
        try {
          _emergencies.add(AmbulanceRequest.fromJson(msg['request'] as Map<String, dynamic>));
        } catch (e) {
          debugPrint("Alerte d'urgence illisible : $e");
        }
    }
  }

  void _onEnded(Map<String, dynamic> msg) {
    final callId = msg['callId'];
    // Erreur avant l'attribution d'un identifiant (ex. aucun rendez-vous avec ce contact)
    if (callId != null && callId != _callId) return;
    if (callId == null && _phase != CallPhase.outgoing) return;
    final wasIncoming = _phase == CallPhase.incoming;
    final notice = switch (msg['reason']) {
      'rejected' => 'Appel refusé',
      'busy' => 'Votre correspondant est déjà en ligne',
      'timeout' => 'Pas de réponse',
      'unavailable' => 'Votre correspondant n\'est pas connecté',
      'cancelled' => wasIncoming ? 'Appel manqué' : null,
      'hangup' => 'Appel terminé',
      'disconnected' => 'Communication interrompue',
      'answered_elsewhere' => null,
      _ => msg['message'] as String? ?? 'Appel terminé',
    };
    _endLocally(notice);
  }

  Future<void> _onSignal(Map<String, dynamic> data) async {
    final pc = _pc;
    if (pc == null) return;
    try {
      if (data['sdp'] != null) {
        await pc.setRemoteDescription(RTCSessionDescription(data['sdp'] as String, data['type'] as String));
        _remoteDescriptionSet = true;
        for (final candidate in _pendingCandidates) {
          await pc.addCandidate(candidate);
        }
        _pendingCandidates.clear();
        if (data['type'] == 'offer') {
          final answer = await pc.createAnswer();
          await pc.setLocalDescription(answer);
          _send({
            'type': 'signal',
            'callId': _callId,
            'data': {'type': answer.type, 'sdp': answer.sdp}
          });
        }
      } else if (data['candidate'] != null) {
        final candidate = RTCIceCandidate(
          data['candidate'] as String,
          data['sdpMid'] as String?,
          (data['sdpMLineIndex'] as num?)?.toInt(),
        );
        if (_remoteDescriptionSet) {
          await pc.addCandidate(candidate);
        } else {
          // Candidat arrivé avant l'offre/la réponse : appliqué dès qu'elle est reçue
          _pendingCandidates.add(candidate);
        }
      }
    } catch (e) {
      debugPrint('Appels : signal WebRTC ignoré ($e)');
    }
  }

  // ---------------------------------------------------------------- WebRTC

  Future<void> _ensureRenderers() => _renderersReady ??= Future.wait([
        localRenderer.initialize(),
        remoteRenderer.initialize(),
      ]);

  /// Micro (et caméra pour un appel vidéo). En cas de refus, l'appel est abandonné.
  Future<bool> _openMedia() async {
    try {
      await _ensureRenderers();
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': _video ? {'facingMode': 'user'} : false,
      });
      localRenderer.srcObject = _localStream;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Appels : accès micro/caméra refusé ($e)');
      _endLocally(_video
          ? 'Accès au micro et à la caméra refusé : autorisez-les pour appeler'
          : 'Accès au micro refusé : autorisez-le pour appeler');
      return false;
    }
  }

  Future<void> _createPeerConnection() async {
    final pc = await createPeerConnection({'iceServers': _iceServers, 'sdpSemantics': 'unified-plan'});
    _pc = pc;
    for (final track in _localStream?.getTracks() ?? const <MediaStreamTrack>[]) {
      await pc.addTrack(track, _localStream!);
    }
    pc.onIceCandidate = (candidate) {
      if (candidate.candidate == null) return;
      _send({
        'type': 'signal',
        'callId': _callId,
        'data': {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      });
    };
    pc.onTrack = (event) {
      if (event.streams.isEmpty) return;
      remoteRenderer.srcObject = event.streams.first;
      if (_phase != CallPhase.active) {
        _phase = CallPhase.active;
        _connectedAt = DateTime.now();
      }
      notifyListeners();
    };
    pc.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed && _phase != CallPhase.idle) {
        if (_callId != null) _send({'type': 'hangup', 'callId': _callId});
        _endLocally('Connexion audio/vidéo impossible avec votre correspondant');
      }
    };
  }

  Future<void> _makeOffer() async {
    try {
      await _createPeerConnection();
      final offer = await _pc!.createOffer();
      await _pc!.setLocalDescription(offer);
      _send({
        'type': 'signal',
        'callId': _callId,
        'data': {'type': offer.type, 'sdp': offer.sdp}
      });
    } catch (e) {
      debugPrint('Appels : offre impossible ($e)');
      hangUp();
    }
  }

  // ---------------------------------------------------------------- Interne

  void _send(Map<String, dynamic> payload) {
    _channel?.sink.add(jsonEncode(payload));
  }

  void _endLocally(String? notice) {
    _reset();
    if (notice != null) _notices.add(notice);
  }

  void _reset({bool keepCancelFlag = false}) {
    _pc?.close();
    _pc = null;
    for (final track in _localStream?.getTracks() ?? const <MediaStreamTrack>[]) {
      track.stop();
    }
    _localStream?.dispose();
    _localStream = null;
    if (_renderersReady != null) {
      localRenderer.srcObject = null;
      remoteRenderer.srcObject = null;
    }
    _pendingCandidates.clear();
    _remoteDescriptionSet = false;
    _phase = CallPhase.idle;
    _callId = null;
    _peer = null;
    _connectedAt = null;
    _micMuted = false;
    _cameraOff = false;
    if (!keepCancelFlag) _cancelWhenRinging = false;
    notifyListeners();
  }

  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _wanted = false;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _reset();
    localRenderer.dispose();
    remoteRenderer.dispose();
    _notices.close();
    _emergencies.close();
    _transportRequests.close();
    _orderUpdates.close();
    _invoiceUpdates.close();
    _missionUpdates.close();
    _doctorStatus.close();
    _samuDismissTimer?.cancel();
    super.dispose();
  }
}
