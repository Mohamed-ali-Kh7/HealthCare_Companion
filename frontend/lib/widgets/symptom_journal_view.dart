import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/utils/formatters.dart';
import '../models/symptom_entry.dart';

/// Évolution du journal de symptômes : choix de la mesure, graphique, moyenne et tendance,
/// puis le détail jour par jour. Utilisé côté patient et côté médecin.
class SymptomJournalView extends StatefulWidget {
  const SymptomJournalView({super.key, required this.entries, this.days = 14, this.onTapEntry});

  /// Entrées triées par date croissante (format renvoyé par l'API).
  final List<SymptomEntry> entries;
  final int days;
  final void Function(SymptomEntry entry)? onTapEntry;

  @override
  State<SymptomJournalView> createState() => _SymptomJournalViewState();
}

class _SymptomJournalViewState extends State<SymptomJournalView> {
  SymptomMetric _metric = SymptomMetric.pain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateUtils.dateOnly(DateTime.now());
    final start = today.subtract(Duration(days: widget.days - 1));
    final inPeriod = widget.entries.where((e) => !e.date.isBefore(start)).toList();
    final values = [for (final e in inPeriod) if (_metric.valueOf(e) != null) _metric.valueOf(e)!];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<SymptomMetric>(
            showSelectedIcon: false,
            segments: [
              for (final m in SymptomMetric.values) ButtonSegment(value: m, icon: Icon(m.icon), label: Text(m.label)),
            ],
            selected: {_metric},
            onSelectionChanged: (s) => setState(() => _metric = s.first),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_metric.label} · ${widget.days} derniers jours', style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                _Headline(metric: _metric, values: values, entries: inPeriod),
                const SizedBox(height: 8),
                SymptomChart(entries: inPeriod, metric: _metric, start: start, days: widget.days),
                Text('${inPeriod.length}/${widget.days} jours renseignés',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (final e in inPeriod.reversed) _EntryTile(entry: e, onTap: widget.onTapEntry),
      ],
    );
  }
}

/// Moyenne, dernière valeur et tendance (2e moitié de la période comparée à la 1re).
class _Headline extends StatelessWidget {
  const _Headline({required this.metric, required this.values, required this.entries});

  final SymptomMetric metric;
  final List<double> values;
  final List<SymptomEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (values.isEmpty) {
      return Text('Aucune valeur sur la période', style: TextStyle(color: theme.colorScheme.onSurfaceVariant));
    }
    final avg = values.reduce((a, b) => a + b) / values.length;
    final half = values.length ~/ 2;
    String trend = '';
    if (half >= 2) {
      double mean(Iterable<double> v) => v.reduce((a, b) => a + b) / v.length;
      final delta = mean(values.skip(half)) - mean(values.take(half));
      final threshold = (metric.max - metric.min) * 0.08;
      // Pour la douleur et la température, une baisse est une amélioration
      final lowerIsBetter = metric == SymptomMetric.pain || metric == SymptomMetric.temperature;
      if (delta.abs() < threshold) {
        trend = ' · stable';
      } else {
        final better = lowerIsBetter ? delta < 0 : delta > 0;
        trend = better ? ' · en amélioration ↗' : ' · en dégradation ↘';
      }
    }
    final feverDays = metric == SymptomMetric.temperature ? entries.where((e) => e.hasFever).length : 0;
    return Text.rich(TextSpan(children: [
      TextSpan(
          text: 'Moyenne ${metric.format(avg)}',
          style: theme.textTheme.titleLarge?.copyWith(color: metric.color, fontWeight: FontWeight.w600)),
      TextSpan(text: '  · dernière ${metric.format(values.last)}$trend'),
      if (feverDays > 0)
        TextSpan(
            text: '\n$feverDays jour(s) de fièvre (≥ 38 °C)',
            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
    ]));
  }
}

/// Courbe d'une mesure jour par jour. Les jours non remplis coupent la courbe (aucune valeur inventée).
class SymptomChart extends StatelessWidget {
  const SymptomChart({
    super.key,
    required this.entries,
    required this.metric,
    required this.start,
    required this.days,
  });

  final List<SymptomEntry> entries;
  final SymptomMetric metric;
  final DateTime start;
  final int days;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.bodySmall;
    final byDay = {for (final e in entries) DateUtils.dateOnly(e.date): e};
    final spots = <FlSpot>[
      for (var i = 0; i < days; i++)
        switch (byDay[start.add(Duration(days: i))]) {
          final e? when metric.valueOf(e) != null => FlSpot(i.toDouble(), metric.valueOf(e)!),
          _ => FlSpot.nullSpot,
        },
    ];
    final labelEvery = days <= 7 ? 1 : (days <= 14 ? 2 : 5);

    return AspectRatio(
      aspectRatio: 1.8,
      child: LineChart(LineChartData(
        minX: 0,
        maxX: (days - 1).toDouble(),
        minY: metric.min,
        maxY: metric.max,
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        extraLinesData: ExtraLinesData(horizontalLines: [
          if (metric == SymptomMetric.temperature)
            HorizontalLine(
              y: SymptomMetric.feverThreshold,
              color: Colors.red.withValues(alpha: 0.6),
              strokeWidth: 1,
              dashArray: [6, 4],
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topRight,
                style: const TextStyle(color: Colors.red, fontSize: 10),
                labelResolver: (_) => 'fièvre',
              ),
            ),
        ]),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: metric == SymptomMetric.mood ? 1 : (metric == SymptomMetric.temperature ? 1 : 2),
              getTitlesWidget: (v, meta) => Text(
                  metric == SymptomMetric.mood ? (moodEmojis[v.round()] ?? '') : v.toInt().toString(),
                  style: labelStyle),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: 1,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i % labelEvery != 0 && i != days - 1) return const SizedBox.shrink();
                final d = start.add(Duration(days: i));
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('${d.day}/${d.month}', style: labelStyle),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem(
                  '${Fmt.date(start.add(Duration(days: s.x.toInt())))}\n${metric.format(s.y)}',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            color: metric.color,
            barWidth: 3,
            isCurved: false,
            dotData: FlDotData(
              getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                radius: 4,
                color: metric == SymptomMetric.temperature && spot.y >= SymptomMetric.feverThreshold
                    ? Colors.red
                    : metric.color,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(show: true, color: metric.color.withValues(alpha: 0.08)),
          ),
        ],
      )),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, this.onTap});

  final SymptomEntry entry;
  final void Function(SymptomEntry entry)? onTap;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final parts = [
      if (e.pain != null) 'Douleur ${e.pain}/10',
      if (e.mood != null) '${moodEmojis[e.mood]} ${moodLabels[e.mood]}',
      if (e.sleepHours != null) 'Sommeil ${SymptomMetric.sleep.format(e.sleepHours!)}',
      if (e.temperature != null) '${e.temperature!.toStringAsFixed(1)} °C',
    ];
    return Card(
      child: ListTile(
        leading: Icon(e.hasFever ? Icons.thermostat : Icons.event_note, color: e.hasFever ? Colors.red : null),
        title: Text(Fmt.dateLong(e.date)),
        subtitle: Text([parts.join(' · '), if (e.note != null) '« ${e.note} »'].join('\n')),
        isThreeLine: e.note != null,
        trailing: onTap == null ? null : const Icon(Icons.edit_outlined),
        onTap: onTap == null ? null : () => onTap!(e),
      ),
    );
  }
}
