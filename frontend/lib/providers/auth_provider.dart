import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../core/storage/token_storage.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// État de session global : qui est connecté et avec quel rôle.
/// L'interface (app.dart) choisit l'espace à afficher selon [user.role].
class AuthProvider extends ChangeNotifier {
  AuthProvider({
    required AuthService authService,
    required TokenStorage tokenStorage,
    required ApiClient apiClient,
  })  : _authService = authService,
        _tokenStorage = tokenStorage {
    // Token expiré/invalide détecté sur n'importe quel appel → retour à l'écran de connexion
    apiClient.onUnauthorized = () => _expireSession();
  }

  final AuthService _authService;
  final TokenStorage _tokenStorage;

  AuthStatus _status = AuthStatus.unknown;
  User? _user;
  String? _sessionMessage;

  AuthStatus get status => _status;
  User? get user => _user;

  /// Message à afficher sur l'écran de connexion (ex : session expirée).
  String? consumeSessionMessage() {
    final message = _sessionMessage;
    _sessionMessage = null;
    return message;
  }

  /// Au démarrage : un token stocké est-il encore valide ?
  Future<void> restoreSession() async {
    final token = await _tokenStorage.read();
    if (token == null) {
      _setUnauthenticated();
      return;
    }
    try {
      _user = await _authService.me();
      _status = AuthStatus.authenticated;
      notifyListeners();
    } on ApiException catch (e) {
      if (e.code == 'NETWORK_ERROR') {
        _sessionMessage = e.message;
      } else {
        await _tokenStorage.clear();
      }
      _setUnauthenticated();
    }
  }

  Future<void> login(String email, String password) async {
    final response = await _authService.login(email.trim(), password);
    await _startSession(response);
  }

  Future<void> registerPatient({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
    String? dateOfBirth,
  }) async {
    final response = await _authService.registerPatient(
      email: email.trim(),
      password: password,
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      phone: phone,
      dateOfBirth: dateOfBirth,
    );
    await _startSession(response);
  }

  Future<void> logout() async {
    await _tokenStorage.clear();
    _user = null;
    _setUnauthenticated();
  }

  Future<void> _startSession(AuthResponse response) async {
    await _tokenStorage.save(response.accessToken);
    _user = response.user;
    _status = AuthStatus.authenticated;
    notifyListeners();
  }

  Future<void> _expireSession() async {
    if (_status != AuthStatus.authenticated) return;
    _sessionMessage = 'Votre session a expiré. Veuillez vous reconnecter.';
    await logout();
  }

  void _setUnauthenticated() {
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
