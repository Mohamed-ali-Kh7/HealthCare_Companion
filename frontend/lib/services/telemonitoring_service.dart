import '../core/network/api_client.dart';
import '../models/sensor.dart';

class TelemonitoringService {
  TelemonitoringService(this._api);

  final ApiClient _api;

  /// Envoi groupé (max 500 mesures). Idempotent côté serveur : un renvoi ne crée pas de doublon.
  Future<SensorBatchResult> send(List<SensorReading> readings) async {
    final json = await _api.post('/api/sensor-data',
        body: {'readings': readings.map((r) => r.toJson()).toList()});
    return SensorBatchResult.fromJson(json as Map<String, dynamic>);
  }

  Future<List<DailySummary>> getMySummary(SensorType type, {int days = 7}) async =>
      _summary(await _api.get('/api/sensor-data/my/summary',
          query: {'type': type.apiValue, 'days': days}));

  /// Médecin traitant uniquement.
  Future<List<DailySummary>> getPatientSummary(int patientId, SensorType type, {int days = 7}) async =>
      _summary(await _api.get('/api/sensor-data/patients/$patientId/summary',
          query: {'type': type.apiValue, 'days': days}));

  List<DailySummary> _summary(dynamic json) =>
      (json as List).map((e) => DailySummary.fromJson(e as Map<String, dynamic>)).toList();
}
