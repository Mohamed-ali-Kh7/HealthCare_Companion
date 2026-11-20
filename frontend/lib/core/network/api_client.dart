import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

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

  /// [timeout] : pour les requêtes longues (ex. assistant santé), sinon AppConfig.requestTimeout.
  Future<dynamic> post(String path, {Object? body, Map<String, dynamic>? query, Duration? timeout}) =>
      _send('POST', path, body: body, query: query, timeout: timeout);

  Future<dynamic> put(String path, {Object? body}) => _send('PUT', path, body: body);

  Future<dynamic> patch(String path, {Object? body}) => _send('PATCH', path, body: body);

  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Duration? timeout,
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

    final response = await _execute(request, timeout: timeout);
    final text = utf8.decode(response.bodyBytes);
    final dynamic decoded = text.isEmpty ? null : _tryDecode(text);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }
    _throwError(response, decoded, token, path);
  }

  /// Envoi d'un fichier (multipart/form-data), ex. message vocal. Renvoie le JSON de la réponse.
  Future<dynamic> postFile(
    String path, {
    required String field,
    required List<int> bytes,
    required String filename,
    required String contentType,
    Map<String, String> fields = const {},
  }) async {
    final request = http.MultipartRequest('POST', _buildUri(path, null))
      ..headers[HttpHeaders.acceptHeader] = 'application/json'
      ..fields.addAll(fields)
      ..files.add(http.MultipartFile.fromBytes(field, bytes,
          filename: filename, contentType: MediaType.parse(contentType)));
    final token = await tokenStorage.read();
    if (token != null) {
      request.headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
    }

    final response = await _execute(request);
    final text = utf8.decode(response.bodyBytes);
    final dynamic decoded = text.isEmpty ? null : _tryDecode(text);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }
    _throwError(response, decoded, token, path);
  }

  /// Téléchargement binaire authentifié (ex. audio d'un message vocal), avec son type de contenu.
  Future<({Uint8List bytes, String? contentType})> download(String path) async {
    final request = http.Request('GET', _buildUri(path, null));
    final token = await tokenStorage.read();
    if (token != null) {
      request.headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
    }
    final response = await _execute(request);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return (bytes: response.bodyBytes, contentType: response.headers['content-type']);
    }
    final text = utf8.decode(response.bodyBytes, allowMalformed: true);
    _throwError(response, text.isEmpty ? null : _tryDecode(text), token, path);
  }

  Future<http.Response> _execute(http.BaseRequest request, {Duration? timeout}) async {
    try {
      final streamed = await _http.send(request).timeout(timeout ?? AppConfig.requestTimeout);
      return await http.Response.fromStream(streamed);
    } on SocketException {
      throw ApiException.network();
    } on TimeoutException {
      throw ApiException.network();
    } on http.ClientException {
      throw ApiException.network();
    }
  }

  Never _throwError(http.Response response, dynamic decoded, String? token, String path) {
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
