import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/utils/formatters.dart';
import '../models/doctor.dart';
import '../services/doctor_service.dart';
import 'ui_helpers.dart';

/// Médecin : pastille « Disponible / Absent » (barre du haut). Charge elle-même le statut ;
/// un appui ouvre [AwaySheet]. [onChanged] : statut mis à jour (ex. pour afficher un bandeau).
class DoctorAvailabilityChip extends StatefulWidget {
  const DoctorAvailabilityChip({super.key, this.onChanged});

  final ValueChanged<Doctor>? onChanged;

  @override
  State<DoctorAvailabilityChip> createState() => _DoctorAvailabilityChipState();
}

class _DoctorAvailabilityChipState extends State<DoctorAvailabilityChip> {
  Doctor? _me;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final me = await context.read<DoctorService>().getMyProfile();
      if (!mounted) return;
      setState(() => _me = me);
      widget.onChanged?.call(me);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _edit() async {
    final me = _me;
    if (me == null) return _load();
    final updated = await showAwaySheet(context, me);
    if (updated != null && mounted) {
      setState(() => _me = updated);
      widget.onChanged?.call(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = _me;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ActionChip(
        tooltip: 'Ma disponibilité (visible par mes patients)',
        avatar: me == null
            ? (_failed
                ? const Icon(Icons.refresh, size: 18)
                : const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)))
            : Icon(me.away ? Icons.event_busy : Icons.check_circle,
                size: 18, color: me.away ? Colors.deepOrange : Colors.green),
        label: Text(me == null ? (_failed ? 'Réessayer' : 'Statut…') : (me.away ? 'Absent' : 'Disponible')),
        onPressed: _edit,
      ),
    );
  }
}

/// Ouvre la fenêtre « Ma disponibilité » ; renvoie le profil mis à jour (null si annulé).
Future<Doctor?> showAwaySheet(BuildContext context, Doctor current) => showModalBottomSheet<Doctor>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AwaySheet(current: current),
    );

/// Médecin : absent / disponible, avec message et date de retour facultatifs.
class AwaySheet extends StatefulWidget {
  const AwaySheet({super.key, required this.current});

  final Doctor current;

  @override
  State<AwaySheet> createState() => _AwaySheetState();
}

class _AwaySheetState extends State<AwaySheet> {
  late bool _away = widget.current.away;
  late final _message = TextEditingController(text: widget.current.awayMessage ?? '');
  late DateTime? _until = widget.current.awayUntil;
  bool _saving = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _until ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Absent jusqu\'au (inclus)',
    );
    if (picked != null) setState(() => _until = picked);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final updated = await context.read<DoctorService>().setAway(
            away: _away,
            message: _message.text.trim().isEmpty ? null : _message.text.trim(),
            until: _until,
          );
      if (!mounted) return;
      showSnack(context, _away ? 'Vos patients sont prévenus de votre absence' : 'Vous êtes de nouveau disponible');
      Navigator.of(context).pop(updated);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showSnack(context, errorMessage(e), isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Ma disponibilité', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _away,
            onChanged: (v) => setState(() => _away = v),
            title: const Text('Je suis absent / indisponible'),
            subtitle: const Text('Vos patients sont prévenus dans leur messagerie et peuvent transférer leurs '
                'questions à l\'assistant santé.'),
          ),
          if (_away) ...[
            TextField(
              controller: _message,
              maxLength: 300,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Message aux patients (optionnel)',
                hintText: 'Ex : en congé, pour une urgence appelez le 190',
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(_until == null ? 'Sans date de retour' : 'Absent jusqu\'au ${Fmt.date(_until)}'),
              subtitle: const Text('Après cette date, vous redevenez disponible automatiquement'),
              trailing: _until == null
                  ? TextButton(onPressed: _pickDate, child: const Text('Choisir'))
                  : IconButton(
                      tooltip: 'Retirer la date',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _until = null),
                    ),
              onTap: _pickDate,
            ),
          ],
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}
