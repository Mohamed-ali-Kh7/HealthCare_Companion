import '../core/network/api_client.dart';
import '../core/utils/formatters.dart';
import '../models/ambulance_request.dart';

class AmbulanceService {
  AmbulanceService(this._api);

  final ApiClient _api;

  static const _base = '/api/ambulance-requests';

  // ---------------------------------------------------------------- Patient

  /// Urgence : envoyée immédiatement, sans validation.
  Future<AmbulanceRequest> sendEmergency(
          {double? lat, double? lng, String? reason}) async =>
      _one(await _api.post(_base, body: {
        'type': AmbulanceRequestType.emergency.apiValue,
        'latitude': lat,
        'longitude': lng,
        'reason': reason,
      }));

  /// Transport programmé : soumis à la validation du médecin choisi.
  Future<AmbulanceRequest> requestTransport({
    required int doctorId,
    required String address,
    required DateTime scheduledAt,
    String? reason,
    double? lat,
    double? lng,
  }) async =>
      _one(await _api.post(_base, body: {
        'type': AmbulanceRequestType.scheduled.apiValue,
        'doctorId': doctorId,
        'address': address,
        'scheduledAt': Fmt.apiLocalDateTime(scheduledAt),
        'reason': reason,
        'latitude': lat,
        'longitude': lng,
      }));

  Future<List<AmbulanceRequest>> getMine() async =>
      _list(await _api.get('$_base/my'));

  Future<AmbulanceRequest> cancel(int id) async =>
      _one(await _api.put('$_base/$id/cancel'));

  /// Patient ou médecin référent : urgence résolue / transport effectué.
  Future<AmbulanceRequest> close(int id) async =>
      _one(await _api.put('$_base/$id/close'));

  // ---------------------------------------------------------------- Médecin

  Future<List<AmbulanceRequest>> getForDoctor() async =>
      _list(await _api.get('$_base/doctor'));

  Future<AmbulanceRequest> takeCharge(int id, {String? note}) async =>
      _one(await _api.put('$_base/$id/take-charge', body: {'note': note}));

  Future<AmbulanceRequest> approve(int id, {String? note}) async =>
      _one(await _api.put('$_base/$id/approve', body: {'note': note}));

  Future<AmbulanceRequest> reject(int id, {String? note}) async =>
      _one(await _api.put('$_base/$id/reject', body: {'note': note}));

  List<AmbulanceRequest> _list(dynamic json) => (json as List)
      .map((e) => AmbulanceRequest.fromJson(e as Map<String, dynamic>))
      .toList();

  AmbulanceRequest _one(dynamic json) =>
      AmbulanceRequest.fromJson(json as Map<String, dynamic>);
}
