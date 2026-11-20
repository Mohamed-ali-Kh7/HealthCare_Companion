import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../models/symptom_entry.dart';
import '../../services/journal_service.dart';
import '../../widgets/ui_helpers.dart';

/// Saisie d'une journée du journal. Chaque mesure peut être laissée vide (case à décocher).
/// Renvoie true (Navigator.pop) après enregistrement ou suppression.
class SymptomEntryFormScreen extends StatefulWidget {
  const SymptomEntryFormScreen({super.key, required this.date, this.existing});

  final DateTime date;
  final SymptomEntry? existing;

  @override
  State<SymptomEntryFormScreen> createState() => _SymptomEntryFormScreenState();
}

class _SymptomEntryFormScreenState extends State<SymptomEntryFormScreen> {
  late final SymptomEntry? _e = widget.existing;
  late bool _withPain = _e == null || _e.pain != null;
  late double _pain = (_e?.pain ?? 0).toDouble();
  late int? _mood = _e?.mood;
  late bool _withSleep = _e == null || _e.sleepHours != null;
  late double _sleep = _e?.sleepHours ?? 7;
  late bool _withTemperature = _e?.temperature != null;
  late double _temperature = _e?.temperature ?? 37.0;
  late final _note = TextEditingController(text: _e?.note ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final entry = SymptomEntry(
      date: widget.date,
      pain: _withPain ? _pain.round() : null,
      mood: _mood,
      sleepHours: _withSleep ? _sleep : null,
      temperature: _withTemperature ? double.parse(_temperature.toStringAsFixed(1)) : null,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
    );
    setState(() => _saving = true);
    final ok = await runWithFeedback(context, () => context.read<JournalService>().save(entry),
        successMessage: 'Journal enregistré');
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final ok = await confirm(context,
        title: 'Supprimer cette journée ?', message: Fmt.dateLong(widget.date), confirmLabel: 'Supprimer', destructive: true);
    if (!ok || !mounted) return;
    final done = await runWithFeedback(context, () => context.read<JournalService>().delete(widget.date),
        successMessage: 'Journée supprimée');
    if (done && mounted) Navigator.of(context).pop(true);
  }

  static String _painLabel(int v) => switch (v) {
        0 => 'Aucune douleur',
        <= 3 => 'Légère',
        <= 6 => 'Modérée',
        <= 8 => 'Forte',
        _ => 'Insupportable',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateUtils.isSameDay(widget.date, DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Text(today ? 'Mon journal du jour' : Fmt.date(widget.date)),
        actions: [
          if (widget.existing != null)
            IconButton(tooltip: 'Supprimer', icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(Fmt.dateLong(widget.date), style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),

          // Douleur 0-10
          _Section(
            icon: SymptomMetric.pain.icon,
            color: SymptomMetric.pain.color,
            title: 'Douleur',
            value: _withPain ? '${_pain.round()}/10 · ${_painLabel(_pain.round())}' : 'Non renseignée',
            enabled: _withPain,
            onEnabled: (v) => setState(() => _withPain = v),
            child: Slider(
              value: _pain,
              max: 10,
              divisions: 10,
              label: '${_pain.round()}',
              activeColor: SymptomMetric.pain.color,
              onChanged: (v) => setState(() => _pain = v),
            ),
          ),

          // Humeur 1-5
          _Section(
            icon: SymptomMetric.mood.icon,
            color: SymptomMetric.mood.color,
            title: 'Humeur',
            value: _mood == null ? 'Non renseignée' : moodLabels[_mood]!,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (var m = 1; m <= 5; m++)
                  InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => setState(() => _mood = _mood == m ? null : m),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _mood == m ? SymptomMetric.mood.color.withValues(alpha: 0.15) : null,
                        border: Border.all(color: _mood == m ? SymptomMetric.mood.color : Colors.transparent, width: 2),
                      ),
                      child: Text(moodEmojis[m]!, style: TextStyle(fontSize: _mood == m ? 32 : 26)),
                    ),
                  ),
              ],
            ),
          ),

          // Sommeil
          _Section(
            icon: SymptomMetric.sleep.icon,
            color: SymptomMetric.sleep.color,
            title: 'Sommeil (nuit dernière)',
            value: _withSleep ? SymptomMetric.sleep.format(_sleep) : 'Non renseigné',
            enabled: _withSleep,
            onEnabled: (v) => setState(() => _withSleep = v),
            child: Slider(
              value: _sleep,
              max: 12,
              divisions: 24,
              label: SymptomMetric.sleep.format(_sleep),
              activeColor: SymptomMetric.sleep.color,
              onChanged: (v) => setState(() => _sleep = v),
            ),
          ),

          // Température / fièvre
          _Section(
            icon: SymptomMetric.temperature.icon,
            color: SymptomMetric.temperature.color,
            title: 'Température',
            value: !_withTemperature
                ? 'Non mesurée'
                : '${_temperature.toStringAsFixed(1)} °C${_temperature >= SymptomMetric.feverThreshold ? ' · fièvre' : ''}',
            enabled: _withTemperature,
            onEnabled: (v) => setState(() => _withTemperature = v),
            child: Slider(
              value: _temperature,
              min: 35,
              max: 41,
              divisions: 60,
              label: '${_temperature.toStringAsFixed(1)} °C',
              activeColor: _temperature >= SymptomMetric.feverThreshold ? Colors.red : SymptomMetric.temperature.color,
              onChanged: (v) => setState(() => _temperature = v),
            ),
          ),

          const SizedBox(height: 8),
          TextField(
            controller: _note,
            maxLength: 500,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Remarques (optionnel)',
              hintText: 'Ex : maux de tête le soir, toux, nausées…',
              prefixIcon: Icon(Icons.notes),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check),
            label: const Text('Enregistrer'),
          ),
          const SizedBox(height: 8),
          Text('Vos médecins voient l\'évolution de votre journal avant la consultation.',
              textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.child,
    this.enabled = true,
    this.onEnabled,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final Widget child;
  final bool enabled;
  final ValueChanged<bool>? onEnabled;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleSmall),
                      Text(value, style: TextStyle(color: enabled ? color : Colors.grey, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                if (onEnabled != null) Switch(value: enabled, onChanged: onEnabled),
              ],
            ),
            if (enabled) child,
          ],
        ),
      ),
    );
  }
}
