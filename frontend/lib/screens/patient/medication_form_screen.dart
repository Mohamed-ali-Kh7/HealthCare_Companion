import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../models/medication.dart';
import '../../models/medicine.dart';
import '../../services/medication_service.dart';
import '../../widgets/medicine_picker.dart';
import '../../widgets/ui_helpers.dart';

/// Ajout manuel ou modification d'un traitement du carnet (posologie, dates, heures de rappel).
/// Renvoie true via Navigator.pop si une modification a été enregistrée.
class MedicationFormScreen extends StatefulWidget {
  const MedicationFormScreen({super.key, this.medication});

  final Medication? medication;

  @override
  State<MedicationFormScreen> createState() => _MedicationFormScreenState();
}

class _MedicationFormScreenState extends State<MedicationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _dosage;
  Medicine? _medicine;
  late int _timesPerDay;
  late DateTime _startDate;
  DateTime? _endDate;
  late List<TimeOfDay> _reminders;
  late bool _active;
  bool _saving = false;

  bool get _isEdit => widget.medication != null;

  @override
  void initState() {
    super.initState();
    final m = widget.medication;
    _medicine = m?.medicine;
    _dosage = TextEditingController(text: m?.actualDosage ?? '1 comprimé');
    _timesPerDay = m?.timesPerDay ?? 1;
    _startDate = m?.startDate ?? DateTime.now();
    _endDate = m?.endDate;
    _active = m?.active ?? true;
    _reminders = m == null
        ? _defaultReminders(_timesPerDay)
        : m.reminderTimes.map((t) {
            final p = ApiDates.parseTime(t);
            return TimeOfDay(hour: p.hour, minute: p.minute);
          }).toList();
  }

  @override
  void dispose() {
    _dosage.dispose();
    super.dispose();
  }

  /// Même répartition que le backend : prises entre 08:00 et 20:00.
  static List<TimeOfDay> _defaultReminders(int n) {
    if (n <= 1) return [const TimeOfDay(hour: 8, minute: 0)];
    final interval = (12 * 60) ~/ (n - 1);
    return [
      for (var i = 0; i < n; i++)
        TimeOfDay(hour: 8 + (i * interval) ~/ 60, minute: (i * interval) % 60),
    ];
  }

  Future<void> _pickMedicine() async {
    final picked = await pickMedicine(context);
    if (picked != null) setState(() => _medicine = picked);
  }

  Future<void> _pickDate({required bool start}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _startDate : (_endDate ?? _startDate),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _pickReminder(int index) async {
    final picked = await showTimePicker(context: context, initialTime: _reminders[index]);
    if (picked != null) setState(() => _reminders[index] = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_medicine == null) {
      showSnack(context, 'Choisissez un médicament', isError: true);
      return;
    }
    if (_endDate != null && _endDate!.isBefore(_startDate)) {
      showSnack(context, 'La date de fin précède la date de début', isError: true);
      return;
    }

    final request = <String, dynamic>{
      'medicineId': _medicine!.id,
      'actualDosage': _dosage.text.trim(),
      'timesPerDay': _timesPerDay,
      'startDate': Fmt.apiDate(_startDate),
      'endDate': _endDate == null ? null : Fmt.apiDate(_endDate!),
      'reminderTimes': _reminders.map((t) => Fmt.apiTime(t.hour, t.minute)).toList(),
      'active': _active,
    };

    setState(() => _saving = true);
    final service = context.read<MedicationService>();
    final ok = await runWithFeedback(
      context,
      () => _isEdit ? service.update(widget.medication!.id, request) : service.create(request),
      successMessage: 'Traitement enregistré',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Modifier le traitement' : 'Nouveau traitement')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.medication),
                title: Text(_medicine?.displayName ?? 'Choisir un médicament'),
                trailing: _isEdit ? null : const Icon(Icons.search),
                onTap: _isEdit ? null : _pickMedicine,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _dosage,
              decoration: const InputDecoration(labelText: 'Dose par prise (ex : 1 comprimé)'),
              validator: Validators.required,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(child: Text('Prises par jour')),
                IconButton(
                  onPressed: _timesPerDay > 1
                      ? () => setState(() {
                            _timesPerDay--;
                            _reminders = _defaultReminders(_timesPerDay);
                          })
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('$_timesPerDay', style: Theme.of(context).textTheme.titleLarge),
                IconButton(
                  onPressed: _timesPerDay < 6
                      ? () => setState(() {
                            _timesPerDay++;
                            _reminders = _defaultReminders(_timesPerDay);
                          })
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              children: [
                for (var i = 0; i < _reminders.length; i++)
                  ActionChip(
                    avatar: const Icon(Icons.alarm, size: 18),
                    label: Text(_reminders[i].format(context)),
                    onPressed: () => _pickReminder(i),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.play_arrow_outlined),
              title: const Text('Début'),
              subtitle: Text(Fmt.date(_startDate)),
              onTap: () => _pickDate(start: true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.stop_outlined),
              title: const Text('Fin'),
              subtitle: Text(_endDate == null ? 'Aucune (au long cours)' : Fmt.date(_endDate)),
              onTap: () => _pickDate(start: false),
              trailing: _endDate == null
                  ? null
                  : IconButton(
                      tooltip: 'Retirer la date de fin',
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _endDate = null),
                    ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Rappels actifs'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}
