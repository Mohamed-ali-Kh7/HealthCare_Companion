import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_companion/core/network/api_exception.dart';
import 'package:healthcare_companion/core/utils/formatters.dart';
import 'package:healthcare_companion/widgets/ui_helpers.dart';

void main() {
  group('Validators.password (même politique que le backend)', () {
    test('refuse un mot de passe trop court ou sans chiffre', () {
      expect(Validators.password('abc'), isNotNull);
      expect(Validators.password('abcdefgh'), isNotNull);
    });

    test('accepte 8+ caractères avec lettre et chiffre', () {
      expect(Validators.password('Secret123'), isNull);
    });
  });

  test('ApiException lit le format ProblemDetail', () {
    final e = ApiException.fromJson(400, {
      'code': 'VALIDATION_FAILED',
      'detail': 'Données invalides',
      'errors': {'email': 'Email invalide'},
    });
    expect(e.code, 'VALIDATION_FAILED');
    expect(e.displayMessage, 'Données invalides : Email invalide');
  });

  test('Fmt produit les formats attendus par l\'API', () {
    final d = DateTime(2026, 3, 7, 9, 5);
    expect(Fmt.apiDate(d), '2026-03-07');
    expect(Fmt.apiLocalDateTime(d), '2026-03-07T09:05:00');
    expect(Fmt.apiTime(8, 0), '08:00');
  });
}
