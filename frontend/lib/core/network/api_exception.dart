/// Erreur renvoyée par l'API au format ProblemDetail (RFC 9457) :
/// {"status":409,"code":"EMAIL_ALREADY_USED","detail":"...","errors":{"email":"..."}}
class ApiException implements Exception {
  ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.fieldErrors = const {},
  });

  final int statusCode;
  final String code;
  final String message;
  final Map<String, String> fieldErrors;

  factory ApiException.fromJson(int statusCode, Map<String, dynamic> json) {
    final errors = <String, String>{};
    final rawErrors = json['errors'];
    if (rawErrors is Map) {
      rawErrors.forEach((key, value) => errors['$key'] = '$value');
    }
    return ApiException(
      statusCode: statusCode,
      code: (json['code'] as String?) ?? 'HTTP_$statusCode',
      message: (json['detail'] as String?) ?? (json['title'] as String?) ?? 'Erreur $statusCode',
      fieldErrors: errors,
    );
  }

  factory ApiException.network() => ApiException(
        statusCode: 0,
        code: 'NETWORK_ERROR',
        message: 'Serveur injoignable. Vérifiez votre connexion.',
      );

  bool get isUnauthorized => statusCode == 401;

  /// Message prêt à afficher : détail + première erreur de champ éventuelle.
  String get displayMessage {
    if (fieldErrors.isEmpty) return message;
    return '$message : ${fieldErrors.values.first}';
  }

  @override
  String toString() => 'ApiException($statusCode, $code, $message)';
}
