import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/utils/formatters.dart';
import '../models/sensor.dart';

/// Histogramme journalier : total de pas, ou moyenne pour la fréquence cardiaque / l'activité.
class DailySensorChart extends StatelessWidget {
  const DailySensorChart({super.key, required this.data, required this.type});

  final List<DailySummary> data;
  final SensorType type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final values = data.map((d) => d.valueFor(type)).toList();
    final hasData = data.any((d) => d.count > 0);

    if (!hasData) {
      return SizedBox(
        height: 160,
        child: Center(
          child: Text('Aucune mesure sur la période',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
        ),
      );
    }

    final maxValue = values.reduce(math.max);
    final maxY = maxValue <= 0 ? 1.0 : maxValue * 1.2;
    final labelStyle = theme.textTheme.bodySmall;

    return AspectRatio(
      aspectRatio: 1.7,
      child: Padding(
        padding: const EdgeInsets.only(top: 16, right: 8),
        child: BarChart(
          BarChartData(
            maxY: maxY,
            alignment: BarChartAlignment.spaceAround,
            borderData: FlBorderData(show: false),
            gridData: const FlGridData(show: true, drawVerticalLine: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 44,
                  // Le maximum (non arrondi) chevaucherait la dernière graduation
                  getTitlesWidget: (value, meta) => value == meta.max
                      ? const SizedBox.shrink()
                      : Text(value.toInt().toString(), style: labelStyle),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i >= data.length) return const SizedBox.shrink();
                    // Jour et numéro sur deux lignes : 7 libellés ne tiennent pas sur une ligne
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(Fmt.dayShort(data[i].date).replaceFirst(' ', '\n'),
                          textAlign: TextAlign.center, style: labelStyle),
                    );
                  },
                ),
              ),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                  '${rod.toY.toStringAsFixed(type == SensorType.steps ? 0 : 1)} ${type.unit}',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < values.length; i++)
                BarChartGroupData(x: i, barRods: [
                  BarChartRodData(
                    toY: values[i],
                    width: 16,
                    color: theme.colorScheme.primary,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ]),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bloc titre + indicateur clé + graphique, utilisé côté patient et côté médecin.
class SensorSummaryCard extends StatelessWidget {
  const SensorSummaryCard({super.key, required this.type, required this.data});

  final SensorType type;
  final List<DailySummary> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = data.where((d) => d.count > 0).toList();
    final String headline;
    if (days.isEmpty) {
      headline = '—';
    } else if (type == SensorType.steps) {
      final avg = days.map((d) => d.sum).reduce((a, b) => a + b) / days.length;
      headline = '${avg.round()} pas / jour en moyenne';
    } else {
      final avg = days.map((d) => d.avg).reduce((a, b) => a + b) / days.length;
      headline = '${avg.toStringAsFixed(1)} ${type.unit} en moyenne';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(type.label, style: theme.textTheme.titleMedium),
            Text(headline,
                style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.primary)),
            DailySensorChart(data: data, type: type),
          ],
        ),
      ),
    );
  }
}
