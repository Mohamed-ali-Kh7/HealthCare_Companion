import '../core/network/api_client.dart';
import '../models/medication.dart';

/// Carnet de suivi du patient.
class MedicationService {
  MedicationService(this._api);

  final ApiClient _api;

  Future<List<Medication>> getMine() async {
    final json = await _api.get('/api/medications') as List;
    return json.map((e) => Medication.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// [request] : medicineId (création), actualDosage, timesPerDay, startDate, endDate,
  /// reminderTimes (["08:00", ...]) et active.
  Future<Medication> create(Map<String, dynamic> request) async =>
      Medication.fromJson(await _api.post('/api/medications', body: request) as Map<String, dynamic>);

  Future<Medication> update(int id, Map<String, dynamic> request) async =>
      Medication.fromJson(await _api.put('/api/medications/$id', body: request) as Map<String, dynamic>);

  Future<void> delete(int id) => _api.delete('/api/medications/$id');
}
