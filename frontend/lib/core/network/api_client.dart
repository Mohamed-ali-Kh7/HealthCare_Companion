import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';

/// Client HTTP unique de l'application.
/// - ajoute automatiquement "Authorization: Bearer <token>" ;
/// - décode le JSON et transforme les erreurs ProblemDetail en [ApiException] ;
/// - prévient l'application (onUnauthorized) quand le token est expiré ou invalide.
///
/// Les écrans ne l'utilisent jamais directement : ils passent par les services (lib/services).
class ApiClient {
  ApiClient({required this.tokenStorage, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final TokenStorage tokenStorage;
  final http.Client _http;

  /// Appelé sur une réponse 401 d'une route protégée (session expirée) : déconnexion.
  void Function()? onUnauthorized;

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(String path, {Object? body, Map<String, dynamic>? query}) =>
      _send('POST', path, body: body, query: query);

  Future<dynamic> put(String path, {Object? body}) => _send('PUT', path, body: body);

  Future<dynamic> patch(String path, {Object? body}) => _send('PATCH', path, body: body);

  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async {
    final uri = _buildUri(path, query);
    final request = http.Request(method, uri)
      ..headers[HttpHeaders.acceptHeader] = 'application/json';

    final token = await tokenStorage.read();
    if (token != null) {
      request.headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
    }
    if (body != null) {
      request.headers[HttpHeaders.contentTypeHeader] = 'application/json; charset=utf-8';
      request.body = jsonEncode(body);
    }

    final http.Response response;
    try {
      final streamed = await _http.send(request).timeout(AppConfig.requestTimeout);
      response = await http.Response.fromStream(streamed);
    } on SocketException {
      throw ApiException.network();
    } on TimeoutException {
      throw ApiException.network();
    } on http.ClientException {
      throw ApiException.network();
    }

    final text = utf8.decode(response.bodyBytes);
    final dynamic decoded = text.isEmpty ? null : _tryDecode(text);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    final error = decoded is Map<String, dynamic>
        ? ApiException.fromJson(response.statusCode, decoded)
        : ApiException(
            statusCode: response.statusCode,
            code: 'HTTP_${response.statusCode}',
            message: 'Erreur ${response.statusCode}',
          );

    if (error.isUnauthorized && token != null && !path.startsWith('/api/auth/login')) {
      onUnauthorized?.call();
    }
    throw error;
  }

  Uri _buildUri(String path, Map<String, dynamic>? query) {
    final params = <String, String>{};
    query?.forEach((key, value) {
      if (value != null && '$value'.isNotEmpty) params[key] = '$value';
    });
    final base = Uri.parse('${AppConfig.apiBaseUrl}$path');
    return params.isEmpty ? base : base.replace(queryParameters: params);
  }

  dynamic _tryDecode(String text) {
    try {
      return jsonDecode(text);
    } on FormatException {
      return null;
    }
  }
}
