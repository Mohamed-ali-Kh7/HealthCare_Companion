import '../core/network/api_client.dart';
import '../models/order.dart';

class OrderService {
  OrderService(this._api);

  final ApiClient _api;

  static const _base = '/api/orders';

  // ---------------------------------------------------------------- Patient

  Future<MedicineOrder> create({
    required OrderType type,
    required int pharmacyId,
    required int medicineId,
    required int quantity,
    String? deliveryAddress,
    String? phone,
    String? note,
  }) async =>
      _one(await _api.post(_base, body: {
        'type': type.apiValue,
        'pharmacyId': pharmacyId,
        'medicineId': medicineId,
        'quantity': quantity,
        'deliveryAddress': deliveryAddress,
        'phone': phone,
        'note': note,
      }));

  Future<List<MedicineOrder>> getMine() async => _list(await _api.get('$_base/my'));

  Future<MedicineOrder> cancel(int id) async => _one(await _api.put('$_base/$id/cancel'));

  // ---------------------------------------------------------------- Pharmacien

  Future<List<MedicineOrder>> getForPharmacy() async => _list(await _api.get('$_base/pharmacy'));

  Future<MedicineOrder> confirm(int id, {String? note}) async =>
      _one(await _api.put('$_base/$id/confirm', body: {'note': note}));

  Future<MedicineOrder> reject(int id, {String? note}) async =>
      _one(await _api.put('$_base/$id/reject', body: {'note': note}));

  Future<MedicineOrder> complete(int id) async => _one(await _api.put('$_base/$id/complete'));

  List<MedicineOrder> _list(dynamic json) =>
      (json as List).map((e) => MedicineOrder.fromJson(e as Map<String, dynamic>)).toList();

  MedicineOrder _one(dynamic json) => MedicineOrder.fromJson(json as Map<String, dynamic>);
}
