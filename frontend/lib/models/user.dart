import '../core/utils/formatters.dart';

enum UserRole {
  patient('PATIENT', 'Patient'),
  doctor('DOCTOR', 'Médecin'),
  pharmacist('PHARMACIST', 'Pharmacien'),
  ambulanceCompany('AMBULANCE_COMPANY', "Société d'ambulance"),
  admin('ADMIN', 'Administrateur');

  const UserRole(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static UserRole fromApi(String value) =>
      UserRole.values.firstWhere((r) => r.apiValue == value);
}

class User {
  const User({
    required this.id,
    required this.email,
    required this.role,
    required this.enabled,
    this.emailVerified = true,
    this.createdAt,
  });

  final int id;
  final String email;
  final UserRole role;
  final bool enabled;

  /// false : inscrit mais l'adresse doit être confirmée avec le code reçu par e-mail.
  final bool emailVerified;
  final DateTime? createdAt;

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as int,
        email: json['email'] as String,
        role: UserRole.fromApi(json['role'] as String),
        enabled: json['enabled'] as bool,
        emailVerified: (json['emailVerified'] as bool?) ?? true,
        createdAt: ApiDates.parseInstant(json['createdAt']),
      );
}

/// Réponse de connexion / inscription / vérification d'e-mail.
/// Sans [accessToken] : pas de session (e-mail à vérifier ou compte en attente de validation).
class AuthResponse {
  const AuthResponse({required this.accessToken, required this.expiresIn, required this.user});

  final String? accessToken;
  final int expiresIn;
  final User user;

  bool get hasSession => accessToken != null && accessToken!.isNotEmpty;

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
        accessToken: json['accessToken'] as String?,
        expiresIn: (json['expiresIn'] as int?) ?? 0,
        user: User.fromJson(json['user'] as Map<String, dynamic>),
      );
}
