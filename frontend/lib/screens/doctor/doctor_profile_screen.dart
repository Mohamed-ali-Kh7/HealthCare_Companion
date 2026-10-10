import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/doctor.dart';
import '../../models/speciality.dart';
import '../../services/doctor_service.dart';
import '../../widgets/async_view.dart';
import '../../widgets/ui_helpers.dart';

class DoctorProfileScreen extends StatelessWidget {
  const DoctorProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<DoctorService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Profil professionnel')),
      body: AsyncView<(Doctor, List<Speciality>)>(
        load: () async => (await service.getMyProfile(), await service.getSpecialities()),
        builder: (context, data, _) => _DoctorForm(doctor: data.$1, specialities: data.$2),
      ),
    );
  }
}

class _DoctorForm extends StatefulWidget {
  const _DoctorForm({required this.doctor, required this.specialities});

  final Doctor doctor;
  final List<Speciality> specialities;

  @override
  State<_DoctorForm> createState() => _DoctorFormState();
}

class _DoctorFormState extends State<_DoctorForm> {
  static const _durations = [10, 15, 20, 30, 45, 60];

  final _formKey = GlobalKey<FormState>();
  late final _firstName = TextEditingController(text: widget.doctor.firstName);
  late final _lastName = TextEditingController(text: widget.doctor.lastName);
  late final _phone = TextEditingController(text: widget.doctor.phone ?? '');
  late final _address = TextEditingController(text: widget.doctor.address);
  late final _bio = TextEditingController(text: widget.doctor.bio ?? '');
  late int _specialityId = widget.doctor.speciality.id;
  late int _duration = widget.doctor.consultationDurationMinutes;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_firstName, _lastName, _phone, _address, _bio]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await runWithFeedback(
      context,
      () => context.read<DoctorService>().updateMyProfile(
            firstName: _firstName.text.trim(),
            lastName: _lastName.text.trim(),
            phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
            address: _address.text.trim(),
            specialityId: _specialityId,
            bio: _bio.text.trim().isEmpty ? null : _bio.text.trim(),
            consultationDurationMinutes: _duration,
          ),
      successMessage: 'Profil mis à jour',
    );
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 14);
    final durations = {..._durations, _duration}.toList()..sort();
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextFormField(
              controller: _firstName,
              decoration: const InputDecoration(labelText: 'Prénom'),
              validator: Validators.required),
          gap,
          TextFormField(
              controller: _lastName,
              decoration: const InputDecoration(labelText: 'Nom'),
              validator: Validators.required),
          gap,
          DropdownButtonFormField<int>(
            initialValue: _specialityId,
            decoration: const InputDecoration(labelText: 'Spécialité'),
            items: [
              for (final s in widget.specialities) DropdownMenuItem(value: s.id, child: Text(s.name)),
            ],
            onChanged: (v) => setState(() => _specialityId = v ?? _specialityId),
          ),
          gap,
          TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Téléphone du cabinet'),
              validator: Validators.phone),
          gap,
          TextFormField(
              controller: _address,
              decoration: const InputDecoration(labelText: 'Adresse du cabinet'),
              validator: Validators.required),
          gap,
          DropdownButtonFormField<int>(
            initialValue: _duration,
            decoration: const InputDecoration(labelText: 'Durée d\'une consultation'),
            items: [for (final d in durations) DropdownMenuItem(value: d, child: Text('$d minutes'))],
            onChanged: (v) => setState(() => _duration = v ?? _duration),
          ),
          gap,
          TextFormField(
            controller: _bio,
            maxLength: 1000,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Présentation (visible par les patients)'),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _saving ? null : _save, child: const Text('Enregistrer')),
        ],
      ),
    );
  }
}
