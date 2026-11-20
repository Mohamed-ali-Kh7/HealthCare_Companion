import 'package:flutter/material.dart';

import '../core/utils/formatters.dart';

/// Libellés de l'humeur (1 à 5).
const moodLabels = {1: 'Très mauvaise', 2: 'Mauvaise', 3: 'Moyenne', 4: 'Bonne', 5: 'Très bonne'};
const moodEmojis = {1: '😞', 2: '🙁', 3: '😐', 4: '🙂', 5: '😄'};

/// Une journée du journal de symptômes. Chaque mesure est facultative.
class SymptomEntry {
  const SymptomEntry({
    required this.date,
    this.id,
    this.pain,
    this.mood,
    this.sleepHours,
    this.temperature,
    this.note,
  });

  final int? id;
  final DateTime date;
  final int? pain;
  final int? mood;
  final double? sleepHours;
  final double? temperature;
  final String? note;

  bool get hasFever => temperature != null && temperature! >= SymptomMetric.feverThreshold;

  factory SymptomEntry.fromJson(Map<String, dynamic> json) => SymptomEntry(
        id: json['id'] as int?,
        date: ApiDates.parseLocal(json['date'])!,
        pain: json['pain'] as int?,
        mood: json['mood'] as int?,
        sleepHours: (json['sleepHours'] as num?)?.toDouble(),
        temperature: (json['temperature'] as num?)?.toDouble(),
        note: json['note'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'date': Fmt.apiDate(date),
        'pain': pain,
        'mood': mood,
        'sleepHours': sleepHours,
        'temperature': temperature,
        'note': note,
      };
}

/// Mesure affichable sur le graphique d'évolution.
enum SymptomMetric {
  pain('Douleur', '/10', Icons.healing, Colors.deepOrange, 0, 10),
  mood('Humeur', '/5', Icons.mood, Colors.indigo, 1, 5),
  sleep('Sommeil', 'h', Icons.bedtime, Colors.teal, 0, 12),
  temperature('Température', '°C', Icons.thermostat, Colors.red, 35, 41);

  const SymptomMetric(this.label, this.unit, this.icon, this.color, this.min, this.max);

  final String label;
  final String unit;
  final IconData icon;
  final Color color;
  final double min;
  final double max;

  static const feverThreshold = 38.0;

  double? valueOf(SymptomEntry e) => switch (this) {
        SymptomMetric.pain => e.pain?.toDouble(),
        SymptomMetric.mood => e.mood?.toDouble(),
        SymptomMetric.sleep => e.sleepHours,
        SymptomMetric.temperature => e.temperature,
      };

  String format(double v) => switch (this) {
        SymptomMetric.pain || SymptomMetric.mood => '${v.round()}$unit',
        SymptomMetric.sleep => '${_trim(v)} $unit',
        SymptomMetric.temperature => '${v.toStringAsFixed(1)} $unit',
      };

  static String _trim(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}
