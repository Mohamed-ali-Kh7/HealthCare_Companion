import '../core/network/api_client.dart';
import '../models/doctor.dart';
import '../models/page_response.dart';
import '../models/speciality.dart';

/// Médecins, planning et référentiel des spécialités.
class DoctorService {
  DoctorService(this._api);

  final ApiClient _api;

  Future<PageResponse<Doctor>> search({String? query, int? specialityId, int page = 0}) async {
    final json = await _api.get('/api/doctors', query: {
      'q': query,
      'specialityId': specialityId,
      'page': page,
      'size': 20,
    });
    return PageResponse.fromJson(json as Map<String, dynamic>, Doctor.fromJson);
  }

  Future<Doctor> getById(int id) async =>
      Doctor.fromJson(await _api.get('/api/doctors/$id') as Map<String, dynamic>);

  Future<Doctor> getMyProfile() async =>
      Doctor.fromJson(await _api.get('/api/doctors/me') as Map<String, dynamic>);

  Future<Doctor> updateMyProfile({
    required String firstName,
    required String lastName,
    required String address,
    required int specialityId,
    required int consultationDurationMinutes,
    String? phone,
    String? bio,
  }) async {
    final json = await _api.put('/api/doctors/me', body: {
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
      'address': address,
      'specialityId': specialityId,
      'bio': bio,
      'consultationDurationMinutes': consultationDurationMinutes,
    });
    return Doctor.fromJson(json as Map<String, dynamic>);
  }

  Future<List<Availability>> getAvailabilities(int doctorId) async =>
      _availabilities(await _api.get('/api/doctors/$doctorId/availabilities'));

  Future<List<Availability>> getMyAvailabilities() async =>
      _availabilities(await _api.get('/api/doctors/me/availabilities'));

  Future<List<Availability>> replaceMyAvailabilities(List<Availability> items) async =>
      _availabilities(await _api.put('/api/doctors/me/availabilities',
          body: {'availabilities': items.map((a) => a.toJson()).toList()}));

  List<Availability> _availabilities(dynamic json) =>
      (json as List).map((e) => Availability.fromJson(e as Map<String, dynamic>)).toList();

  // ---------------------------------------------------------------- Spécialités

  Future<List<Speciality>> getSpecialities() async {
    final json = await _api.get('/api/specialities') as List;
    return json.map((e) => Speciality.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Speciality> createSpeciality(String name, String? description) async =>
      Speciality.fromJson(await _api.post('/api/specialities',
          body: {'name': name, 'description': description}) as Map<String, dynamic>);

  Future<Speciality> updateSpeciality(int id, String name, String? description) async =>
      Speciality.fromJson(await _api.put('/api/specialities/$id',
          body: {'name': name, 'description': description}) as Map<String, dynamic>);

  Future<void> deleteSpeciality(int id) => _api.delete('/api/specialities/$id');
}
