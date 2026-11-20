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

  /// Société d'ambulance conventionnée : compte actif après validation par l'administrateur.
  Future<User> registerAmbulanceCompany({
    required String email,
    required String password,
    required String companyName,
    required String conventionNumber,
    required String address,
    required String city,
    required String phone,
    required double latitude,
    required double longitude,
  }) async {
    final json = await _api.post('/api/auth/register/ambulance-company', body: {
      'email': email,
      'password': password,
      'companyName': companyName,
      'conventionNumber': conventionNumber,
      'address': address,
      'city': city,
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

  /// Code reçu par e-mail après l'inscription. Token renvoyé si le compte est actif.
  Future<AuthResponse> verifyEmail(String email, String code) async {
    final json = await _api.post('/api/auth/verify-email', body: {'email': email, 'code': code});
    return AuthResponse.fromJson(json as Map<String, dynamic>);
  }

  Future<void> resendVerification(String email) async {
    await _api.post('/api/auth/resend-verification', body: {'email': email});
  }

  /// Envoie un code de réinitialisation (réponse identique que le compte existe ou non).
  Future<void> forgotPassword(String email) async {
    await _api.post('/api/auth/forgot-password', body: {'email': email});
  }

  Future<void> resetPassword({required String email, required String code, required String newPassword}) async {
    await _api.post('/api/auth/reset-password',
        body: {'email': email, 'code': code, 'newPassword': newPassword});
  }
}
