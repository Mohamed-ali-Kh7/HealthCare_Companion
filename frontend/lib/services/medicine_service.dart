import '../core/network/api_client.dart';
import '../models/medicine.dart';
import '../models/page_response.dart';

/// Référentiel des médicaments (lecture pour tous, écriture admin).
class MedicineService {
  MedicineService(this._api);

  final ApiClient _api;

  Future<PageResponse<Medicine>> search({String? query, int page = 0, int size = 20}) async {
    final json = await _api.get('/api/medicines', query: {'q': query, 'page': page, 'size': size});
    return PageResponse.fromJson(json as Map<String, dynamic>, Medicine.fromJson);
  }

  Future<Medicine> create(Map<String, dynamic> request) async =>
      Medicine.fromJson(await _api.post('/api/medicines', body: request) as Map<String, dynamic>);

  Future<Medicine> update(int id, Map<String, dynamic> request) async =>
      Medicine.fromJson(await _api.put('/api/medicines/$id', body: request) as Map<String, dynamic>);

  Future<void> delete(int id) => _api.delete('/api/medicines/$id');
}
