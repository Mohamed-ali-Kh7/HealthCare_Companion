import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../models/doctor.dart';
import '../../services/doctor_service.dart';
import '../../widgets/async_view.dart';
import '../../widgets/ui_helpers.dart';

/// Planning hebdomadaire du médecin : plages de consultation récurrentes.
/// Les créneaux proposés aux patients sont calculés par l'API à partir de ces plages.
class AvailabilityScreen extends StatelessWidget {
  const AvailabilityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AsyncView<List<Availability>>(
      load: context.read<DoctorService>().getMyAvailabilities,
      builder: (context, items, reload) => _AvailabilityEditor(initial: items),
    );
  }
}

class _AvailabilityEditor extends StatefulWidget {
  const _AvailabilityEditor({required this.initial});

  final List<Availability> initial;

  @override
  State<_AvailabilityEditor> createState() => _AvailabilityEditorState();
}

class _AvailabilityEditorState extends State<_AvailabilityEditor> {
  late List<Availability> _items = [...widget.initial];
  bool _dirty = false;
  bool _saving = false;

  Future<void> _add() async {
    final result = await showDialog<Availability>(
      context: context,
      builder: (_) => const _RangeDialog(),
    );
    if (result == null) return;
    setState(() {
      _items = [..._items, result]..sort(_compare);
      _dirty = true;
    });
  }

  static int _compare(Availability a, Availability b) {
    final days = weekDays.keys.toList();
    final byDay = days.indexOf(a.dayOfWeek).compareTo(days.indexOf(b.dayOfWeek));
    return byDay != 0 ? byDay : a.startTime.compareTo(b.startTime);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    List<Availability>? saved;
    final ok = await runWithFeedback(
      context,
      () async => saved = await context.read<DoctorService>().replaceMyAvailabilities(_items),
      successMessage: 'Planning enregistré',
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok && saved != null) {
        _items = saved!;
        _dirty = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: 'Ajouter une plage',
        onPressed: _add,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Expanded(
            child: _items.isEmpty
                ? const EmptyState(
                    icon: Icons.schedule,
                    message: 'Aucune plage de consultation.\nLes patients ne peuvent pas encore réserver.',
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 88),
                    children: [
                      for (var i = 0; i < _items.length; i++)
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.schedule),
                            title: Text(_items[i].dayLabel),
                            subtitle: Text('${_items[i].startTime} – ${_items[i].endTime}'),
                            trailing: IconButton(
                              tooltip: 'Supprimer',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => setState(() {
                                _items = [..._items]..removeAt(i);
                                _dirty = true;
                              }),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          if (_dirty)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 88, 16),
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save),
                  label: const Text('Enregistrer le planning'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RangeDialog extends StatefulWidget {
  const _RangeDialog();

  @override
  State<_RangeDialog> createState() => _RangeDialogState();
}

class _RangeDialogState extends State<_RangeDialog> {
  String _day = 'MONDAY';
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 12, minute: 0);

  int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;

  Future<void> _pick(bool start) async {
    final picked = await showTimePicker(context: context, initialTime: start ? _start : _end);
    if (picked == null) return;
    setState(() {
      if (start) {
        _start = picked;
      } else {
        _end = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final valid = _minutes(_start) < _minutes(_end);
    return AlertDialog(
      title: const Text('Nouvelle plage'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _day,
            decoration: const InputDecoration(labelText: 'Jour'),
            items: [
              for (final e in weekDays.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => setState(() => _day = v ?? _day),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Début'),
            trailing: Text(_start.format(context)),
            onTap: () => _pick(true),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Fin'),
            trailing: Text(_end.format(context)),
            onTap: () => _pick(false),
          ),
          if (!valid)
            Text('La fin doit être après le début', style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
          onPressed: valid
              ? () => Navigator.pop(
                    context,
                    Availability(
                      dayOfWeek: _day,
                      startTime: Fmt.apiTime(_start.hour, _start.minute),
                      endTime: Fmt.apiTime(_end.hour, _end.minute),
                    ),
                  )
              : null,
          child: const Text('Ajouter'),
        ),
      ],
    );
  }
}
