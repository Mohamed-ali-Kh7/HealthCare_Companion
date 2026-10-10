import '../core/network/api_client.dart';
import '../models/prescription.dart';

class PrescriptionService {
  PrescriptionService(this._api);

  final ApiClient _api;

  Future<List<Prescription>> getMine() async => _list(await _api.get('/api/prescriptions/my'));

  Future<List<Prescription>> getIssuedByMe() async =>
      _list(await _api.get('/api/prescriptions/doctor'));

  Future<List<Prescription>> getPatientHistory(int patientId) async =>
      _list(await _api.get('/api/prescriptions/patient/$patientId'));

  Future<Prescription> getById(int id) async =>
      Prescription.fromJson(await _api.get('/api/prescriptions/$id') as Map<String, dynamic>);

  Future<Prescription> create({
    required int patientId,
    required List<PrescriptionItemDraft> items,
    String? notes,
  }) async {
    final json = await _api.post('/api/prescriptions', body: {
      'patientId': patientId,
      'notes': notes,
      'items': items.map((i) => i.toJson()).toList(),
    });
    return Prescription.fromJson(json as Map<String, dynamic>);
  }

  List<Prescription> _list(dynamic json) =>
      (json as List).map((e) => Prescription.fromJson(e as Map<String, dynamic>)).toList();
}
