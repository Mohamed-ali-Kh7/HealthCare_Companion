import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/utils/formatters.dart';

/// Grille de tuiles chiffrées (2 colonnes), commune aux tableaux de bord admin, patient et médecin.
class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: children,
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final String value;

  /// Met la tuile en évidence (élément qui demande une action).
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: highlight ? scheme.tertiaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: scheme.primary),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

/// Répartition horizontale : libellé, barre proportionnelle, valeur.
class BreakdownCard extends StatelessWidget {
  const BreakdownCard({super.key, required this.title, required this.rows, this.labelWidth = 120});

  final String title;
  final List<(String, int)> rows;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    final total = rows.fold<int>(0, (sum, row) => sum + row.$2);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(width: labelWidth, child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : value / total,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    SizedBox(width: 40, child: Text('$value', textAlign: TextAlign.end)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Histogramme d'une valeur par jour (pas quotidiens, rendez-vous à venir...).
class DailyBarChart extends StatelessWidget {
  const DailyBarChart({
    super.key,
    required this.points,
    required this.unit,
    this.emptyMessage = 'Aucune donnée sur la période',
  });

  final List<({DateTime date, double value})> points;
  final String unit;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (points.every((p) => p.value <= 0)) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Text(emptyMessage, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
        ),
      );
    }

    final maxValue = points.map((p) => p.value).reduce(math.max);
    final labelStyle = theme.textTheme.bodySmall;

    return AspectRatio(
      aspectRatio: 1.7,
      child: Padding(
        padding: const EdgeInsets.only(top: 16, right: 8),
        child: BarChart(
          BarChartData(
            maxY: maxValue * 1.2,
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
                  getTitlesWidget: (value, meta) => value == meta.max || value != value.roundToDouble()
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
                    if (i < 0 || i >= points.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(Fmt.dayShort(points[i].date).replaceFirst(' ', '\n'),
                          textAlign: TextAlign.center, style: labelStyle),
                    );
                  },
                ),
              ),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                  '${rod.toY.round()} $unit',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < points.length; i++)
                BarChartGroupData(x: i, barRods: [
                  BarChartRodData(
                    toY: points[i].value,
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
