import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/patient.dart';
import '../../models/prescription.dart';
import '../../services/prescription_service.dart';
import '../../widgets/medicine_picker.dart';
import '../../widgets/ui_helpers.dart';

/// Rédaction d'une ordonnance. Chaque ligne alimente le carnet du patient (rappels automatiques).
class PrescriptionFormScreen extends StatefulWidget {
  const PrescriptionFormScreen({super.key, required this.patient});

  final Patient patient;

  @override
  State<PrescriptionFormScreen> createState() => _PrescriptionFormScreenState();
}

class _PrescriptionFormScreenState extends State<PrescriptionFormScreen> {
  final _notes = TextEditingController();
  final List<PrescriptionItemDraft> _items = [];
  bool _saving = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _addItem() async {
    final medicine = await pickMedicine(context);
    if (medicine == null) return;
    setState(() => _items.add(PrescriptionItemDraft(medicine: medicine)));
  }

  Future<void> _submit() async {
    if (_items.isEmpty) {
      showSnack(context, 'Ajoutez au moins un médicament', isError: true);
      return;
    }
    if (_items.any((i) => i.prescribedDosage.trim().isEmpty)) {
      showSnack(context, 'Chaque ligne doit avoir une posologie', isError: true);
      return;
    }
    setState(() => _saving = true);
    final ok = await runWithFeedback(
      context,
      () => context.read<PrescriptionService>().create(
            patientId: widget.patient.id,
            items: _items,
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          ),
      successMessage: 'Ordonnance enregistrée et transmise au patient',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final allergies = widget.patient.allergies;
    return Scaffold(
      appBar: AppBar(title: Text('Ordonnance · ${widget.patient.fullName}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addItem,
        icon: const Icon(Icons.add),
        label: const Text('Médicament'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          if (allergies != null)
            Card(
              color: Colors.orange.shade50,
              child: ListTile(
                leading: const Icon(Icons.warning_amber, color: Colors.orange),
                title: const Text('Allergies déclarées'),
                subtitle: Text(allergies),
              ),
            ),
          for (var i = 0; i < _items.length; i++) _ItemEditor(
            key: ObjectKey(_items[i]),
            draft: _items[i],
            onRemove: () => setState(() => _items.removeAt(i)),
          ),
          if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text('Aucun médicament. Utilisez le bouton « Médicament » pour en ajouter.',
                  textAlign: TextAlign.center),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _notes,
              maxLength: 1000,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Notes / recommandations (optionnel)'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: const Icon(Icons.send),
              label: const Text('Émettre l\'ordonnance'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemEditor extends StatefulWidget {
  const _ItemEditor({super.key, required this.draft, required this.onRemove});

  final PrescriptionItemDraft draft;
  final VoidCallback onRemove;

  @override
  State<_ItemEditor> createState() => _ItemEditorState();
}

class _ItemEditorState extends State<_ItemEditor> {
  late final _dosage = TextEditingController(text: widget.draft.prescribedDosage);
  late final _instructions = TextEditingController(text: widget.draft.instructions);

  @override
  void dispose() {
    _dosage.dispose();
    _instructions.dispose();
    super.dispose();
  }

  Widget _stepper(String label, int value, int min, int max, ValueChanged<int> onChanged) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        SizedBox(width: 36, child: Text('$value', textAlign: TextAlign.center)),
        IconButton(
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(d.medicine.displayName, style: Theme.of(context).textTheme.titleMedium),
                ),
                IconButton(
                  tooltip: 'Retirer',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: widget.onRemove,
                ),
              ],
            ),
            TextField(
              controller: _dosage,
              decoration: const InputDecoration(labelText: 'Posologie par prise (ex : 1 comprimé)'),
              onChanged: (v) => d.prescribedDosage = v,
            ),
            _stepper('Prises par jour', d.timesPerDay, 1, 6, (v) => setState(() => d.timesPerDay = v)),
            _stepper('Durée (jours)', d.durationDays, 1, 365, (v) => setState(() => d.durationDays = v)),
            TextField(
              controller: _instructions,
              decoration: const InputDecoration(labelText: 'Instructions (ex : au milieu du repas)'),
              onChanged: (v) => d.instructions = v,
            ),
          ],
        ),
      ),
    );
  }
}
