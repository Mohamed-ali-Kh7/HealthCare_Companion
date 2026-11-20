import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../models/appointment.dart';
import '../../services/ambulance_service.dart';
import '../../services/appointment_service.dart';
import '../../widgets/async_view.dart';
import '../../widgets/ui_helpers.dart';

/// Demande de transport sanitaire programmé, à valider par un médecin qui suit le patient.
/// Renvoie true via Navigator.pop si la demande a été créée.
class ScheduledTransportFormScreen extends StatefulWidget {
  const ScheduledTransportFormScreen({super.key});

  @override
  State<ScheduledTransportFormScreen> createState() => _ScheduledTransportFormScreenState();
}

class _ScheduledTransportFormScreenState extends State<ScheduledTransportFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _address = TextEditingController();
  final _reason = TextEditingController();

  int? _doctorId;
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);
  bool _saving = false;

  @override
  void dispose() {
    _address.dispose();
    _reason.dispose();
    super.dispose();
  }

  /// Seuls les médecins avec un rendez-vous accepté ou terminé peuvent valider (règle du backend).
  Future<List<AppointmentDoctor>> _loadDoctors() async {
    final appointments = await context.read<AppointmentService>().getMine();
    final doctors = <int, AppointmentDoctor>{};
    for (final a in appointments) {
      if (a.status == AppointmentStatus.accepted || a.status == AppointmentStatus.completed) {
        doctors[a.doctor.id] = a.doctor;
      }
    }
    return doctors.values.toList();
  }

  DateTime get _scheduledAt => DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 90)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_scheduledAt.isAfter(DateTime.now())) {
      showSnack(context, "L'heure du transport doit être dans le futur", isError: true);
      return;
    }
    setState(() => _saving = true);
    final reason = _reason.text.trim();
    final ok = await runWithFeedback(
      context,
      () => context.read<AmbulanceService>().requestTransport(
            doctorId: _doctorId!,
            address: _address.text.trim(),
            scheduledAt: _scheduledAt,
            reason: reason.isEmpty ? null : reason,
          ),
      successMessage: 'Demande envoyée à votre médecin pour validation',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transport programmé')),
      body: AsyncView<List<AppointmentDoctor>>(
        load: _loadDoctors,
        builder: (context, doctors, _) {
          if (doctors.isEmpty) {
            return const EmptyState(
              icon: Icons.person_search,
              message: 'Un transport doit être validé par un médecin qui vous suit.\n'
                  'Prenez d\'abord un rendez-vous et attendez qu\'il soit accepté.',
            );
          }
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DropdownButtonFormField<int>(
                  initialValue: _doctorId,
                  decoration: const InputDecoration(labelText: 'Médecin qui valide'),
                  items: [
                    for (final d in doctors)
                      DropdownMenuItem(value: d.id, child: Text('${d.fullName} · ${d.specialityName}')),
                  ],
                  onChanged: (v) => setState(() => _doctorId = v),
                  validator: (v) => v == null ? 'Champ obligatoire' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _address,
                  maxLength: 255,
                  decoration: const InputDecoration(labelText: 'Adresse de prise en charge'),
                  validator: Validators.required,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.calendar_today),
                        label: Text(Fmt.date(_date)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickTime,
                        icon: const Icon(Icons.schedule),
                        label: Text(_time.format(context)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _reason,
                  maxLength: 500,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Motif', hintText: 'Optionnel (ex : séance de dialyse)'),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Envoyer la demande'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
