import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:healthcare_companion/core/pdf/prescription_pdf.dart';
import 'package:healthcare_companion/models/prescription.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Comme main.dart : formats de date en français
  setUpAll(() => initializeDateFormatting('fr_FR'));

  final prescription = Prescription.fromJson({
    'id': 12,
    'prescriptionDate': '2026-11-13',
    'notes': 'Revoir dans 10 jours, éviter l\'alcool.',
    'verificationUrl': 'http://localhost:8081/verify/prescription/12-abc',
    'patient': {'id': 1, 'firstName': 'Amira', 'lastName': 'Ben Salah'},
    'doctor': {'id': 1, 'firstName': 'Karim', 'lastName': 'Trabelsi', 'specialityName': 'Médecine générale'},
    'items': [
      {
        'id': 1,
        'medicine': {
          'id': 3,
          'name': 'Paracétamol',
          'activeIngredient': 'Paracétamol',
          'form': 'TABLET',
          'strength': '500 mg',
        },
        'prescribedDosage': '1 comprimé',
        'timesPerDay': 3,
        'durationDays': 5,
        'instructions': 'Après les repas',
      },
    ],
  });

  test('génère un PDF valide pour une ordonnance', () async {
    final bytes = await PrescriptionPdf.build(prescription);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(1000));
    expect(PrescriptionPdf.fileName(prescription), 'ordonnance-12-2026-11-13.pdf');
    // Aperçu manuel : fichier écrit dans le dossier temporaire du système
    File('${Directory.systemTemp.path}/ordonnance-test.pdf').writeAsBytesSync(bytes);
  });
}
