import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/sensor.dart';
import '../../services/telemonitoring_service.dart';
import '../config/app_config.dart';
import '../network/api_exception.dart';

/// Collecte des capteurs du téléphone et envoi périodique à l'API.
///
/// - Podomètre : le capteur renvoie un cumul depuis le démarrage du téléphone ;
///   on envoie la différence depuis le dernier envoi (mémorisée localement).
/// - Accéléromètre : intensité moyenne d'activité sur la période.
/// - Fréquence cardiaque : saisie manuelle (la plupart des téléphones n'ont pas ce capteur).
///
/// Limite : l'envoi automatique tourne tant que l'application est ouverte. Un vrai service
/// d'arrière-plan nécessiterait workmanager / un foreground service Android.
class SensorCollector extends ChangeNotifier {
  SensorCollector(this._service);

  static const _lastCumulativeKey = 'steps_last_cumulative_sent';

  final TelemonitoringService _service;

  StreamSubscription<StepCount>? _stepSub;
  StreamSubscription<UserAccelerometerEvent>? _accelSub;
  Timer? _timer;

  int? _cumulativeSteps;
  double _accelSum = 0;
  int _accelCount = 0;

  bool running = false;
  String? error;
  DateTime? lastSync;
  int? pendingSteps;

  Future<void> start() async {
    if (running) return;
    error = null;

    final permission = await Permission.activityRecognition.request();
    if (!permission.isGranted) {
      error = 'Permission "activité physique" refusée : le podomètre est indisponible.';
    } else {
      _stepSub = Pedometer.stepCountStream.listen(
        _onSteps,
        onError: (Object e) {
          error = 'Podomètre indisponible sur cet appareil.';
          notifyListeners();
        },
      );
    }

    _accelSub = userAccelerometerEventStream(samplingPeriod: SensorInterval.normalInterval).listen(
      (e) {
        _accelSum += math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
        _accelCount++;
      },
      onError: (Object e) => debugPrint('Accéléromètre indisponible : $e'),
    );

    _timer = Timer.periodic(AppConfig.sensorSyncInterval, (_) => sync());
    running = true;
    notifyListeners();
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    final stepSub = _stepSub;
    final accelSub = _accelSub;
    _stepSub = null;
    _accelSub = null;
    running = false;
    notifyListeners();
    // Le plugin podomètre peut lever « No active stream to cancel » : l'arrêt reste effectif
    try {
      await stepSub?.cancel();
    } catch (e) {
      debugPrint('Arrêt du podomètre : $e');
    }
    try {
      await accelSub?.cancel();
    } catch (e) {
      debugPrint('Arrêt de l\'accéléromètre : $e');
    }
  }

  Future<void> _onSteps(StepCount event) async {
    _cumulativeSteps = event.steps;
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_lastCumulativeKey);
    if (last == null) {
      // Première mesure : on fixe la référence pour ne pas envoyer le cumul depuis le démarrage
      await prefs.setInt(_lastCumulativeKey, event.steps);
      pendingSteps = 0;
    } else {
      pendingSteps = _delta(event.steps, last);
    }
    notifyListeners();
  }

  /// Envoie les mesures accumulées. Renvoie le nombre de mesures acceptées.
  Future<int> sync() async {
    final now = DateTime.now();
    final readings = <SensorReading>[];
    final prefs = await SharedPreferences.getInstance();

    final cumulative = _cumulativeSteps;
    if (cumulative != null) {
      final delta = _delta(cumulative, prefs.getInt(_lastCumulativeKey));
      if (delta > 0) {
        readings.add(SensorReading(type: SensorType.steps, value: delta.toDouble(), recordedAt: now));
      }
    }
    if (_accelCount > 0) {
      readings.add(SensorReading(
        type: SensorType.acceleration,
        value: double.parse((_accelSum / _accelCount).toStringAsFixed(2)),
        recordedAt: now,
      ));
    }
    if (readings.isEmpty) return 0;

    try {
      final result = await _service.send(readings);
      if (cumulative != null) await prefs.setInt(_lastCumulativeKey, cumulative);
      _accelSum = 0;
      _accelCount = 0;
      pendingSteps = 0;
      lastSync = now;
      error = null;
      notifyListeners();
      return result.accepted;
    } on ApiException catch (e) {
      error = e.displayMessage;
      notifyListeners();
      return 0;
    }
  }

  Future<void> addHeartRate(int bpm) async {
    await _service.send([
      SensorReading(type: SensorType.heartRate, value: bpm.toDouble(), recordedAt: DateTime.now()),
    ]);
  }

  /// Le cumul repart à 0 après un redémarrage du téléphone.
  /// Plafonné à la borne acceptée par l'API (100 000 pas).
  static int _delta(int current, int? lastSent) {
    final raw = (lastSent == null || current < lastSent) ? current : current - lastSent;
    return math.min(raw, 100000);
  }

  @override
  void dispose() {
    _stepSub?.cancel();
    _accelSub?.cancel();
    _timer?.cancel();
    super.dispose();
  }
}
