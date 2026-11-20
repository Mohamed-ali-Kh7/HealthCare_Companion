import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/symptom_entry.dart';
import '../../services/journal_service.dart';
import '../../widgets/async_view.dart';
import '../../widgets/symptom_journal_view.dart';
import 'symptom_entry_form_screen.dart';

/// Patient : journal de symptômes (saisie du jour, évolution sur 14 ou 30 jours).
class SymptomJournalScreen extends StatefulWidget {
  const SymptomJournalScreen({super.key});

  @override
  State<SymptomJournalScreen> createState() => _SymptomJournalScreenState();
}

class _SymptomJournalScreenState extends State<SymptomJournalScreen> {
  int _days = 14;

  Future<void> _edit(DateTime date, SymptomEntry? existing, Future<void> Function() reload) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => SymptomEntryFormScreen(date: date, existing: existing)),
    );
    if (changed == true) await reload();
  }

  Future<void> _pickPastDay(List<SymptomEntry> entries, Future<void> Function() reload) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.subtract(const Duration(days: 1)),
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now,
      helpText: 'Compléter un jour oublié',
    );
    if (date == null || !mounted) return;
    final existing = entries.where((e) => DateUtils.isSameDay(e.date, date)).firstOrNull;
    await _edit(date, existing, reload);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal de symptômes'),
        actions: [
          PopupMenuButton<int>(
            tooltip: 'Période',
            icon: const Icon(Icons.date_range),
            initialValue: _days,
            onSelected: (d) => setState(() => _days = d),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 7, child: Text('7 jours')),
              PopupMenuItem(value: 14, child: Text('14 jours')),
              PopupMenuItem(value: 30, child: Text('30 jours')),
            ],
          ),
        ],
      ),
      body: AsyncView<List<SymptomEntry>>(
        key: ValueKey(_days),
        load: () => context.read<JournalService>().getMine(days: _days),
        builder: (context, entries, reload) {
          final today = DateTime.now();
          final todayEntry = entries.where((e) => DateUtils.isSameDay(e.date, today)).firstOrNull;
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _TodayCard(entry: todayEntry, onTap: () => _edit(DateUtils.dateOnly(today), todayEntry, reload)),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    icon: const Icon(Icons.history),
                    label: const Text('Compléter un jour oublié'),
                    onPressed: () => _pickPastDay(entries, reload),
                  ),
                ),
                SymptomJournalView(
                  entries: entries,
                  days: _days,
                  onTapEntry: (e) => _edit(e.date, e, reload),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.entry, required this.onTap});

  final SymptomEntry? entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final done = entry != null;
    return Card(
      color: done ? scheme.secondaryContainer : scheme.primaryContainer,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(done ? Icons.check_circle : Icons.edit_calendar, size: 36),
        title: Text(done ? 'Journal du jour rempli' : 'Comment allez-vous aujourd\'hui ?',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(done
            ? 'Touchez pour modifier'
            : 'Notez votre douleur, votre humeur, votre sommeil et votre température (1 minute)'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
