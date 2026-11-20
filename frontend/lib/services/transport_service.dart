import '../core/network/api_client.dart';
import '../models/ambulance_request.dart';
import '../models/transport.dart';

/// Ambulances conventionnées : recherche (patient), profil, flotte et missions (société).
class TransportService {
  TransportService(this._api);

  final ApiClient _api;

  static const _base = '/api/transport';
  static const _requests = '/api/ambulance-requests';

  // ---------------------------------------------------------------- Patient

  Future<List<AmbulanceCompany>> nearby(double lat, double lng, {double? radiusKm}) async {
    final query = 'lat=$lat&lng=$lng${radiusKm == null ? '' : '&radiusKm=$radiusKm'}';
    return (await _api.get('$_base/companies/nearby?$query') as List)
        .map((e) => AmbulanceCompany.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AmbulanceRequest> chooseCompany(int requestId, int companyId) async => AmbulanceRequest.fromJson(
      await _api.put('$_requests/$requestId/company', body: {'companyId': companyId}) as Map<String, dynamic>);

  // ---------------------------------------------------------------- Société

  Future<AmbulanceCompany> getMyCompany() async =>
      AmbulanceCompany.fromJson(await _api.get('$_base/companies/me') as Map<String, dynamic>);

  Future<AmbulanceCompany> updateMyCompany({
    required String name,
    required String address,
    required String city,
    required String phone,
    required double latitude,
    required double longitude,
    required int serviceRadiusKm,
    required bool acceptingRequests,
  }) async =>
      AmbulanceCompany.fromJson(await _api.put('$_base/companies/me', body: {
        'name': name,
        'address': address,
        'city': city,
        'phone': phone,
        'latitude': latitude,
        'longitude': longitude,
        'serviceRadiusKm': serviceRadiusKm,
        'acceptingRequests': acceptingRequests,
      }) as Map<String, dynamic>);

  Future<List<AmbulanceVehicle>> getVehicles() async => (await _api.get('$_base/vehicles') as List)
      .map((e) => AmbulanceVehicle.fromJson(e as Map<String, dynamic>))
      .toList();

  Future<AmbulanceVehicle> saveVehicle({
    int? id,
    required String plate,
    required VehicleType type,
    String? driverName,
    String? driverPhone,
  }) async {
    final body = {'plate': plate, 'type': type.apiValue, 'driverName': driverName, 'driverPhone': driverPhone};
    final json = id == null ? await _api.post('$_base/vehicles', body: body) : await _api.put('$_base/vehicles/$id', body: body);
    return AmbulanceVehicle.fromJson(json as Map<String, dynamic>);
  }

  Future<AmbulanceVehicle> setInService(int id, bool inService) async => AmbulanceVehicle.fromJson(
      await _api.put('$_base/vehicles/$id/service', body: {'inService': inService}) as Map<String, dynamic>);

  Future<List<AmbulanceRequest>> getMissions() async => (await _api.get('$_requests/company') as List)
      .map((e) => AmbulanceRequest.fromJson(e as Map<String, dynamic>))
      .toList();

  Future<AmbulanceRequest> acceptMission(int requestId, int vehicleId, {String? note}) async =>
      AmbulanceRequest.fromJson(await _api.put('$_requests/$requestId/mission/accept',
          body: {'vehicleId': vehicleId, 'note': note}) as Map<String, dynamic>);

  Future<AmbulanceRequest> refuseMission(int requestId, {String? note}) async => AmbulanceRequest.fromJson(
      await _api.put('$_requests/$requestId/mission/refuse', body: {'note': note}) as Map<String, dynamic>);

  Future<AmbulanceRequest> advanceMission(int requestId) async =>
      AmbulanceRequest.fromJson(await _api.put('$_requests/$requestId/mission/advance') as Map<String, dynamic>);
}
