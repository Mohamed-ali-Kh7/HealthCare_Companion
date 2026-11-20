import '../core/network/api_client.dart';
import '../models/stats.dart';

class StatsService {
  StatsService(this._api);

  final ApiClient _api;

  Future<PatientStats> getPatientStats() async => PatientStats.fromJson(
      await _api.get('/api/stats/patient') as Map<String, dynamic>);

  Future<DoctorStats> getDoctorStats() async => DoctorStats.fromJson(
      await _api.get('/api/stats/doctor') as Map<String, dynamic>);
}
