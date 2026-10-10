import '../core/network/api_client.dart';
import '../models/pharmacy.dart';

class PharmacyService {
  PharmacyService(this._api);

  final ApiClient _api;

  Future<List<Pharmacy>> findNearby(double lat, double lng, {double radiusKm = 5}) async {
    final json = await _api.get('/api/pharmacies/nearby',
        query: {'lat': lat, 'lng': lng, 'radiusKm': radiusKm}) as List;
    return json.map((e) => Pharmacy.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<MedicineAvailability>> findAvailability(
    int medicineId,
    double lat,
    double lng, {
    double radiusKm = 10,
  }) async {
    final json = await _api.get('/api/pharmacies/availability', query: {
      'medicineId': medicineId,
      'lat': lat,
      'lng': lng,
      'radiusKm': radiusKm,
    }) as List;
    return json.map((e) => MedicineAvailability.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<StockItem>> getPharmacyStock(int pharmacyId) async =>
      _stock(await _api.get('/api/pharmacies/$pharmacyId/stocks'));

  // ---------------------------------------------------------------- Pharmacien

  Future<Pharmacy> getMine() async =>
      Pharmacy.fromJson(await _api.get('/api/pharmacies/me') as Map<String, dynamic>);

  Future<Pharmacy> updateMine({
    required String name,
    required String address,
    required double latitude,
    required double longitude,
    required bool onDuty,
    String? phone,
    String? openingHours,
  }) async {
    final json = await _api.put('/api/pharmacies/me', body: {
      'name': name,
      'address': address,
      'phone': phone,
      'latitude': latitude,
      'longitude': longitude,
      'openingHours': openingHours,
      'onDuty': onDuty,
    });
    return Pharmacy.fromJson(json as Map<String, dynamic>);
  }

  Future<List<StockItem>> getMyStock() async => _stock(await _api.get('/api/pharmacies/me/stocks'));

  /// Crée ou met à jour la ligne de stock du médicament.
  Future<StockItem> upsertStock({required int medicineId, required int quantity, double? price}) async {
    final json = await _api.put('/api/pharmacies/me/stocks',
        body: {'medicineId': medicineId, 'quantity': quantity, 'price': price});
    return StockItem.fromJson(json as Map<String, dynamic>);
  }

  Future<void> deleteStock(int stockId) => _api.delete('/api/pharmacies/me/stocks/$stockId');

  List<StockItem> _stock(dynamic json) =>
      (json as List).map((e) => StockItem.fromJson(e as Map<String, dynamic>)).toList();
}
