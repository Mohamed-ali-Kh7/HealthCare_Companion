import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_companion/models/symptom_entry.dart';
import 'package:healthcare_companion/widgets/symptom_journal_view.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  final today = DateUtils.dateOnly(DateTime.now());
  // 14 jours dont 2 non remplis ; fièvre les jours 5 à 8 ; douleur en baisse en fin de période
  final entries = [
    for (var d = 13; d >= 0; d--)
      if (d != 3 && d != 10)
        SymptomEntry(
          date: today.subtract(Duration(days: d)),
          pain: d >= 5 && d <= 8 ? 7 : 2,
          mood: d >= 5 && d <= 8 ? 2 : 4,
          sleepHours: 7,
          temperature: d >= 5 && d <= 8 ? 38.6 : 36.8,
          note: d == 7 ? 'Fièvre et courbatures' : null,
        ),
  ];

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: SymptomJournalView(entries: entries, days: 14))),
    ));
  }

  testWidgets('affiche la douleur, puis chaque mesure, sans erreur', (tester) async {
    await pump(tester);
    expect(find.text('Douleur · 14 derniers jours'), findsOneWidget);
    expect(find.text('12/14 jours renseignés'), findsOneWidget);
    expect(find.textContaining('« Fièvre et courbatures »'), findsOneWidget);

    for (final m in [SymptomMetric.mood, SymptomMetric.sleep, SymptomMetric.temperature]) {
      await tester.tap(find.text(m.label).first);
      await tester.pumpAndSettle();
      expect(find.text('${m.label} · 14 derniers jours'), findsOneWidget);
    }
    expect(find.textContaining('4 jour(s) de fièvre'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
