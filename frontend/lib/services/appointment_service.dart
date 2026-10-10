import '../core/network/api_client.dart';
import '../core/utils/formatters.dart';
import '../models/appointment.dart';
import '../models/page_response.dart';

class AppointmentService {
  AppointmentService(this._api);

  final ApiClient _api;

  /// Créneaux libres d'un médecin pour une date.
  Future<List<DateTime>> getSlots(int doctorId, DateTime date) async {
    final json = await _api.get('/api/appointments/slots',
        query: {'doctorId': doctorId, 'date': Fmt.apiDate(date)}) as List;
    return json.map((e) => DateTime.parse(e as String)).toList();
  }

  Future<Appointment> book({required int doctorId, required DateTime slot, String? reason}) async {
    final json = await _api.post('/api/appointments', body: {
      'doctorId': doctorId,
      'appointmentDate': Fmt.apiLocalDateTime(slot),
      'reason': reason,
    });
    return Appointment.fromJson(json as Map<String, dynamic>);
  }

  Future<List<Appointment>> getMine() async => _list(await _api.get('/api/appointments/my'));

  Future<Appointment> cancel(int id) async => _one(await _api.put('/api/appointments/$id/cancel'));

  // ---------------------------------------------------------------- Médecin

  Future<List<Appointment>> getDoctorAppointments({
    AppointmentStatus? status,
    DateTime? from,
    DateTime? to,
  }) async =>
      _list(await _api.get('/api/appointments/doctor', query: {
        'status': status?.apiValue,
        'from': from == null ? null : Fmt.apiDate(from),
        'to': to == null ? null : Fmt.apiDate(to),
      }));

  Future<Appointment> accept(int id) async => _one(await _api.put('/api/appointments/$id/accept'));

  Future<Appointment> reject(int id, {String? note}) async =>
      _one(await _api.put('/api/appointments/$id/reject', body: {'note': note}));

  Future<Appointment> complete(int id, {String? note}) async =>
      _one(await _api.put('/api/appointments/$id/complete', body: {'note': note}));

  // ---------------------------------------------------------------- Admin

  Future<PageResponse<Appointment>> getAll({AppointmentStatus? status, int page = 0}) async {
    final json = await _api.get('/api/appointments',
        query: {'status': status?.apiValue, 'page': page, 'size': 20});
    return PageResponse.fromJson(json as Map<String, dynamic>, Appointment.fromJson);
  }

  List<Appointment> _list(dynamic json) =>
      (json as List).map((e) => Appointment.fromJson(e as Map<String, dynamic>)).toList();

  Appointment _one(dynamic json) => Appointment.fromJson(json as Map<String, dynamic>);
}
