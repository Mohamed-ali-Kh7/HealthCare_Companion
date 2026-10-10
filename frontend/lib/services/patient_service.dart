import '../core/network/api_client.dart';
import '../models/patient.dart';

class PatientService {
  PatientService(this._api);

  final ApiClient _api;

  Future<Patient> getMyProfile() async =>
      Patient.fromJson(await _api.get('/api/patients/me') as Map<String, dynamic>);

  Future<Patient> updateMyProfile({
    required String firstName,
    required String lastName,
    String? phone,
    String? dateOfBirth,
    String? bloodGroup,
    String? allergies,
  }) async {
    final json = await _api.put('/api/patients/me', body: {
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
      'dateOfBirth': dateOfBirth,
      'bloodGroup': bloodGroup,
      'allergies': allergies,
    });
    return Patient.fromJson(json as Map<String, dynamic>);
  }

  /// Médecin : patients suivis.
  Future<List<Patient>> getMyPatients() async {
    final json = await _api.get('/api/patients/my-patients') as List;
    return json.map((e) => Patient.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Médecin (relation de soin) ou admin.
  Future<Patient> getById(int id) async =>
      Patient.fromJson(await _api.get('/api/patients/$id') as Map<String, dynamic>);
}
