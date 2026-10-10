import '../core/utils/formatters.dart';

enum SensorType {
  steps('STEPS', 'Pas', 'pas'),
  heartRate('HEART_RATE', 'Fréquence cardiaque', 'bpm'),
  acceleration('ACCELERATION', 'Activité', 'm/s²');

  const SensorType(this.apiValue, this.label, this.unit);

  final String apiValue;
  final String label;
  final String unit;
}

/// Mesure à envoyer à l'API.
class SensorReading {
  const SensorReading({required this.type, required this.value, required this.recordedAt});

  final SensorType type;
  final double value;
  final DateTime recordedAt;

  Map<String, dynamic> toJson() => {
        'type': type.apiValue,
        'value': value,
        'recordedAt': recordedAt.toUtc().toIso8601String(),
      };
}

/// Agrégat journalier renvoyé par /summary.
class DailySummary {
  const DailySummary({
    required this.date,
    required this.count,
    required this.min,
    required this.max,
    required this.avg,
    required this.sum,
  });

  final DateTime date;
  final int count;
  final double min;
  final double max;
  final double avg;
  final double sum;

  factory DailySummary.fromJson(Map<String, dynamic> json) => DailySummary(
        date: ApiDates.parseLocal(json['date'])!,
        count: json['count'] as int,
        min: (json['min'] as num).toDouble(),
        max: (json['max'] as num).toDouble(),
        avg: (json['avg'] as num).toDouble(),
        sum: (json['sum'] as num).toDouble(),
      );

  /// Valeur pertinente selon le type : total pour les pas, moyenne sinon.
  double valueFor(SensorType type) => type == SensorType.steps ? sum : avg;
}

class SensorBatchResult {
  const SensorBatchResult({required this.accepted, required this.duplicates});

  final int accepted;
  final int duplicates;

  factory SensorBatchResult.fromJson(Map<String, dynamic> json) => SensorBatchResult(
        accepted: json['accepted'] as int,
        duplicates: json['duplicates'] as int,
      );
}
