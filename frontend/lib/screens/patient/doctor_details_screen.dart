import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../models/doctor.dart';
import '../../services/appointment_service.dart';
import '../../services/doctor_service.dart';
import '../../widgets/async_view.dart';
import '../../widgets/ui_helpers.dart';

/// Fiche médecin + prise de rendez-vous sur un créneau libre.
class DoctorDetailsScreen extends StatelessWidget {
  const DoctorDetailsScreen({super.key, required this.doctorId});

  final int doctorId;

  @override
  Widget build(BuildContext context) {
    final service = context.read<DoctorService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Médecin')),
      body: AsyncView<(Doctor, List<Availability>)>(
        load: () async => (await service.getById(doctorId), await service.getAvailabilities(doctorId)),
        builder: (context, data, _) => _DoctorDetails(doctor: data.$1, availabilities: data.$2),
      ),
    );
  }
}

class _DoctorDetails extends StatefulWidget {
  const _DoctorDetails({required this.doctor, required this.availabilities});

  final Doctor doctor;
  final List<Availability> availabilities;

  @override
  State<_DoctorDetails> createState() => _DoctorDetailsState();
}

class _DoctorDetailsState extends State<_DoctorDetails> {
  late DateTime _selectedDay;
  List<DateTime> _slots = [];
  DateTime? _selectedSlot;
  bool _loadingSlots = false;
  bool _booking = false;
  final _reason = TextEditingController();

  /// 14 prochains jours (aujourd'hui inclus).
  late final List<DateTime> _days;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _days = [for (var i = 0; i < 14; i++) DateTime(today.year, today.month, today.day + i)];
    _selectedDay = _days.first;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSlots());
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _loadSlots() async {
    setState(() {
      _loadingSlots = true;
      _selectedSlot = null;
    });
    try {
      final slots = await context.read<AppointmentService>().getSlots(widget.doctor.id, _selectedDay);
      if (mounted) setState(() => _slots = slots);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _loadingSlots = false);
    }
  }

  Future<void> _book() async {
    final slot = _selectedSlot;
    if (slot == null) return;
    final ok = await confirm(context,
        title: 'Confirmer le rendez-vous',
        message: '${widget.doctor.fullName}\n${Fmt.dateLong(slot)} à ${Fmt.time(slot)}');
    if (!ok || !mounted) return;

    setState(() => _booking = true);
    final success = await runWithFeedback(
      context,
      () => context.read<AppointmentService>().book(
            doctorId: widget.doctor.id,
            slot: slot,
            reason: _reason.text.trim().isEmpty ? null : _reason.text.trim(),
          ),
      successMessage: 'Demande envoyée : le médecin doit la confirmer',
    );
    if (!mounted) return;
    setState(() => _booking = false);
    if (success) {
      Navigator.pop(context);
    } else {
      _loadSlots(); // le créneau a peut-être été pris entre-temps
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.doctor;
    final theme = Theme.of(context);
    final dayNames = widget.availabilities.map((a) => a.dayLabel).toSet().join(', ');

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: CircleAvatar(
            radius: 28,
            child: Text('${d.firstName[0]}${d.lastName[0]}', style: const TextStyle(fontSize: 20)),
          ),
          title: Text(d.fullName, style: theme.textTheme.titleLarge),
          subtitle: Text(d.speciality.name, style: TextStyle(color: theme.colorScheme.primary)),
        ),
        ListTile(leading: const Icon(Icons.place_outlined), title: Text(d.address)),
        if (d.phone != null) ListTile(leading: const Icon(Icons.phone_outlined), title: Text(d.phone!)),
        ListTile(
          leading: const Icon(Icons.schedule),
          title: Text('Consultation de ${d.consultationDurationMinutes} min'),
          subtitle: Text(dayNames.isEmpty ? 'Planning non renseigné' : 'Consulte : $dayNames'),
        ),
        if (d.bio != null)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(d.bio!)),
        const Divider(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('Prendre rendez-vous', style: theme.textTheme.titleMedium),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 76,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _days.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final day = _days[i];
              final selected = day == _selectedDay;
              return ChoiceChip(
                selected: selected,
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(Fmt.dayShort(day), textAlign: TextAlign.center),
                ),
                onSelected: (_) {
                  setState(() => _selectedDay = day);
                  _loadSlots();
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: _loadingSlots
              ? const Center(child: CircularProgressIndicator())
              : _slots.isEmpty
                  ? Text('Aucun créneau disponible ce jour-là.',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant))
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final slot in _slots)
                          ChoiceChip(
                            label: Text(Fmt.time(slot)),
                            selected: slot == _selectedSlot,
                            onSelected: (_) => setState(() => _selectedSlot = slot),
                          ),
                      ],
                    ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _reason,
            maxLength: 500,
            decoration: const InputDecoration(labelText: 'Motif (optionnel)'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _selectedSlot == null || _booking ? null : _book,
            icon: const Icon(Icons.event_available),
            label: Text(_selectedSlot == null
                ? 'Choisissez un créneau'
                : 'Réserver le ${Fmt.date(_selectedSlot)} à ${Fmt.time(_selectedSlot!)}'),
          ),
        ),
      ],
    );
  }
}
