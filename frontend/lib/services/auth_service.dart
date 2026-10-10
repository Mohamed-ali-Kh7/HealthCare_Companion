import '../core/network/api_client.dart';
import '../models/user.dart';

/// Appels /api/auth/** et gestion du mot de passe.
class AuthService {
  AuthService(this._api);

  final ApiClient _api;

  Future<AuthResponse> login(String email, String password) async {
    final json = await _api.post('/api/auth/login', body: {'email': email, 'password': password});
    return AuthResponse.fromJson(json as Map<String, dynamic>);
  }

  Future<AuthResponse> registerPatient({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
    String? dateOfBirth,
  }) async {
    final json = await _api.post('/api/auth/register/patient', body: {
      'email': email,
      'password': password,
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
      'dateOfBirth': dateOfBirth,
    });
    return AuthResponse.fromJson(json as Map<String, dynamic>);
  }

  /// Compte créé désactivé : en attente de validation par un administrateur.
  Future<User> registerDoctor({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required int specialityId,
    required String address,
    String? phone,
  }) async {
    final json = await _api.post('/api/auth/register/doctor', body: {
      'email': email,
      'password': password,
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
      'specialityId': specialityId,
      'address': address,
    });
    return User.fromJson(json as Map<String, dynamic>);
  }

  Future<User> registerPharmacist({
    required String email,
    required String password,
    required String pharmacyName,
    required String address,
    required double latitude,
    required double longitude,
    String? phone,
  }) async {
    final json = await _api.post('/api/auth/register/pharmacist', body: {
      'email': email,
      'password': password,
      'pharmacyName': pharmacyName,
      'address': address,
      'phone': phone,
      'latitude': latitude,
      'longitude': longitude,
    });
    return User.fromJson(json as Map<String, dynamic>);
  }

  Future<User> me() async {
    final json = await _api.get('/api/auth/me');
    return User.fromJson(json as Map<String, dynamic>);
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    await _api.put('/api/users/me/password',
        body: {'currentPassword': currentPassword, 'newPassword': newPassword});
  }
}
