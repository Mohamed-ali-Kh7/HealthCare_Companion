import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../core/utils/location_helper.dart';
import '../../models/speciality.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../services/doctor_service.dart';
import '../../widgets/ui_helpers.dart';

/// Inscription. Patient : connecté immédiatement.
/// Médecin / pharmacien : compte en attente de validation par un administrateur.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  UserRole _role = UserRole.patient;
  bool _loading = false;

  final _email = TextEditingController();
  final _password = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _pharmacyName = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  DateTime? _dateOfBirth;
  int? _specialityId;
  List<Speciality> _specialities = [];

  @override
  void initState() {
    super.initState();
    _loadSpecialities();
  }

  @override
  void dispose() {
    for (final c in [
      _email, _password, _firstName, _lastName, _phone, _address, _pharmacyName, _latitude, _longitude
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSpecialities() async {
    try {
      final list = await context.read<DoctorService>().getSpecialities();
      if (mounted) setState(() => _specialities = list);
    } catch (_) {
      // Endpoint public ; en cas d'échec, la liste restera vide et l'erreur s'affichera à l'envoi
    }
  }

  Future<void> _useMyLocation() async {
    final point = await LocationHelper.current();
    setState(() {
      _latitude.text = point.lat.toStringAsFixed(6);
      _longitude.text = point.lng.toStringAsFixed(6);
    });
    if (point.isFallback && mounted) {
      showSnack(context, 'Localisation indisponible : position par défaut (Tunis) utilisée.');
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 30),
      firstDate: DateTime(1900),
      lastDate: now.subtract(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final phone = _phone.text.trim().isEmpty ? null : _phone.text.trim();
    try {
      switch (_role) {
        case UserRole.patient:
          await context.read<AuthProvider>().registerPatient(
                email: _email.text,
                password: _password.text,
                firstName: _firstName.text,
                lastName: _lastName.text,
                phone: phone,
                dateOfBirth: _dateOfBirth == null ? null : Fmt.apiDate(_dateOfBirth!),
              );
          return; // session ouverte : app.dart affiche l'espace patient
        case UserRole.doctor:
          await context.read<AuthService>().registerDoctor(
                email: _email.text.trim(),
                password: _password.text,
                firstName: _firstName.text.trim(),
                lastName: _lastName.text.trim(),
                phone: phone,
                specialityId: _specialityId!,
                address: _address.text.trim(),
              );
        case UserRole.pharmacist:
          await context.read<AuthService>().registerPharmacist(
                email: _email.text.trim(),
                password: _password.text,
                pharmacyName: _pharmacyName.text.trim(),
                address: _address.text.trim(),
                phone: phone,
                latitude: double.parse(_latitude.text),
                longitude: double.parse(_longitude.text),
              );
        case UserRole.admin:
          return;
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Demande envoyée'),
          content: const Text(
              'Votre compte a été créé. Il sera actif après validation par un administrateur.'),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _coordinate(String? v, double limit) {
    final value = double.tryParse(v ?? '');
    if (value == null) return 'Coordonnée invalide';
    return value.abs() > limit ? 'Hors limites' : null;
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 14);
    return Scaffold(
      appBar: AppBar(title: const Text('Créer un compte')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              SegmentedButton<UserRole>(
                segments: const [
                  ButtonSegment(value: UserRole.patient, label: Text('Patient'), icon: Icon(Icons.person)),
                  ButtonSegment(
                      value: UserRole.doctor, label: Text('Médecin'), icon: Icon(Icons.medical_services)),
                  ButtonSegment(
                      value: UserRole.pharmacist, label: Text('Pharmacie'), icon: Icon(Icons.local_pharmacy)),
                ],
                selected: {_role},
                onSelectionChanged: (s) => setState(() => _role = s.first),
              ),
              if (_role != UserRole.patient) ...[
                const SizedBox(height: 12),
                const Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('Les comptes professionnels sont validés par un administrateur.'),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: Validators.email,
              ),
              gap,
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Mot de passe', helperText: '8 caractères min., une lettre et un chiffre'),
                validator: Validators.password,
              ),
              gap,
              if (_role == UserRole.pharmacist) ...[
                TextFormField(
                  controller: _pharmacyName,
                  decoration: const InputDecoration(labelText: 'Nom de la pharmacie'),
                  validator: Validators.required,
                ),
                gap,
              ] else ...[
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
              ],
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Téléphone (optionnel)'),
                validator: Validators.phone,
              ),
              gap,
              if (_role == UserRole.patient)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.cake_outlined),
                  title: const Text('Date de naissance (optionnel)'),
                  subtitle: Text(Fmt.date(_dateOfBirth)),
                  trailing: const Icon(Icons.edit_calendar),
                  onTap: _pickBirthDate,
                ),
              if (_role == UserRole.doctor) ...[
                DropdownButtonFormField<int>(
                  initialValue: _specialityId,
                  decoration: const InputDecoration(labelText: 'Spécialité'),
                  items: [
                    for (final s in _specialities) DropdownMenuItem(value: s.id, child: Text(s.name)),
                  ],
                  onChanged: (v) => setState(() => _specialityId = v),
                  validator: (v) => v == null ? 'Choisissez une spécialité' : null,
                ),
                gap,
              ],
              if (_role != UserRole.patient) ...[
                TextFormField(
                  controller: _address,
                  decoration: InputDecoration(
                      labelText: _role == UserRole.doctor ? 'Adresse du cabinet' : 'Adresse de l\'officine'),
                  validator: Validators.required,
                ),
                gap,
              ],
              if (_role == UserRole.pharmacist) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _latitude,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        decoration: const InputDecoration(labelText: 'Latitude'),
                        validator: (v) => _coordinate(v, 90),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _longitude,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        decoration: const InputDecoration(labelText: 'Longitude'),
                        validator: (v) => _coordinate(v, 180),
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: _useMyLocation,
                  icon: const Icon(Icons.my_location),
                  label: const Text('Utiliser ma position actuelle'),
                ),
                gap,
              ],
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Créer mon compte'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
