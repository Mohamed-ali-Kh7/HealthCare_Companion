import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../models/patient.dart';
import '../../services/patient_service.dart';
import '../../widgets/async_view.dart';
import '../../widgets/ui_helpers.dart';

class PatientProfileScreen extends StatelessWidget {
  const PatientProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mon profil')),
      body: AsyncView<Patient>(
        load: context.read<PatientService>().getMyProfile,
        builder: (context, patient, _) => _PatientForm(patient: patient),
      ),
    );
  }
}

class _PatientForm extends StatefulWidget {
  const _PatientForm({required this.patient});

  final Patient patient;

  @override
  State<_PatientForm> createState() => _PatientFormState();
}

class _PatientFormState extends State<_PatientForm> {
  static const _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  final _formKey = GlobalKey<FormState>();
  late final _firstName = TextEditingController(text: widget.patient.firstName);
  late final _lastName = TextEditingController(text: widget.patient.lastName);
  late final _phone = TextEditingController(text: widget.patient.phone ?? '');
  late final _allergies = TextEditingController(text: widget.patient.allergies ?? '');
  late DateTime? _dateOfBirth = widget.patient.dateOfBirth;
  late String? _bloodGroup = widget.patient.bloodGroup;
  bool _saving = false;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _allergies.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await runWithFeedback(
      context,
      () => context.read<PatientService>().updateMyProfile(
            firstName: _firstName.text.trim(),
            lastName: _lastName.text.trim(),
            phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
            dateOfBirth: _dateOfBirth == null ? null : Fmt.apiDate(_dateOfBirth!),
            bloodGroup: _bloodGroup,
            allergies: _allergies.text.trim(),
          ),
      successMessage: 'Profil mis à jour',
    );
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 14);
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.email_outlined),
            title: Text(widget.patient.email),
          ),
          TextFormField(
            controller: _firstName,
            decoration: const InputDecoration(labelText: 'Prénom'),
            validator: Validators.required,
          ),
          gap,
          TextFormField(
            controller: _lastName,
            decoration: const InputDecoration(labelText: 'Nom'),
            validator: Validators.required,
          ),
          gap,
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Téléphone'),
            validator: Validators.phone,
          ),
          gap,
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.cake_outlined),
            title: const Text('Date de naissance'),
            subtitle: Text(Fmt.date(_dateOfBirth)),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _dateOfBirth ?? DateTime(1990),
                firstDate: DateTime(1900),
                lastDate: DateTime.now().subtract(const Duration(days: 1)),
              );
              if (picked != null) setState(() => _dateOfBirth = picked);
            },
          ),
          gap,
          DropdownButtonFormField<String?>(
            initialValue: _bloodGroup,
            decoration: const InputDecoration(labelText: 'Groupe sanguin'),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('Non renseigné')),
              for (final g in _bloodGroups) DropdownMenuItem<String?>(value: g, child: Text(g)),
            ],
            onChanged: (v) => setState(() => _bloodGroup = v),
          ),
          gap,
          TextFormField(
            controller: _allergies,
            maxLength: 500,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Allergies connues'),
          ),
          const SizedBox(height: 8),
          Text(
            'Ces informations sont visibles uniquement par les médecins avec qui vous avez un rendez-vous.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _saving ? null : _save, child: const Text('Enregistrer')),
        ],
      ),
    );
  }
}
