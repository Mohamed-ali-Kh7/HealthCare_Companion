import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stockage chiffré du JWT (jamais dans SharedPreferences, qui est en clair).
class TokenStorage {
  TokenStorage([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  static const _tokenKey = 'jwt_access_token';

  final FlutterSecureStorage _storage;
  String? _cached;

  Future<String?> read() async {
    _cached ??= await _storage.read(key: _tokenKey);
    return _cached;
  }

  Future<void> save(String token) async {
    _cached = token;
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<void> clear() async {
    _cached = null;
    await _storage.delete(key: _tokenKey);
  }
}
