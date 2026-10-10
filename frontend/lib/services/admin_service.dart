import '../core/network/api_client.dart';
import '../models/dashboard.dart';
import '../models/page_response.dart';
import '../models/user.dart';

class AdminService {
  AdminService(this._api);

  final ApiClient _api;

  Future<Dashboard> getDashboard() async =>
      Dashboard.fromJson(await _api.get('/api/admin/dashboard') as Map<String, dynamic>);

  Future<PageResponse<User>> searchUsers({String? query, UserRole? role, bool? enabled, int page = 0}) async {
    final json = await _api.get('/api/users', query: {
      'q': query,
      'role': role?.apiValue,
      'enabled': enabled,
      'page': page,
      'size': 20,
    });
    return PageResponse.fromJson(json as Map<String, dynamic>, User.fromJson);
  }

  /// Activation (validation d'un médecin / pharmacien) ou désactivation d'un compte.
  Future<User> setUserEnabled(int userId, bool enabled) async =>
      User.fromJson(await _api.patch('/api/users/$userId/status', body: {'enabled': enabled})
          as Map<String, dynamic>);
}
