import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/medicine.dart';
import '../../models/page_response.dart';
import '../../models/speciality.dart';
import '../../services/doctor_service.dart';
import '../../services/medicine_service.dart';
import '../../widgets/async_view.dart';
import '../../widgets/ui_helpers.dart';

/// Référentiels gérés par l'administrateur : spécialités médicales et catalogue des médicaments.
class ReferentialsScreen extends StatelessWidget {
  const ReferentialsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(tabs: [Tab(text: 'Spécialités'), Tab(text: 'Médicaments')]),
          Expanded(child: TabBarView(children: [_SpecialitiesTab(), _MedicinesTab()])),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------- Spécialités

class _SpecialitiesTab extends StatefulWidget {
  const _SpecialitiesTab();

  @override
  State<_SpecialitiesTab> createState() => _SpecialitiesTabState();
}

class _SpecialitiesTabState extends State<_SpecialitiesTab> {
  Key _key = UniqueKey();

  Future<void> _edit([Speciality? current]) async {
    final name = TextEditingController(text: current?.name ?? '');
    final description = TextEditingController(text: current?.description ?? '');
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(current == null ? 'Nouvelle spécialité' : 'Modifier la spécialité'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Nom')),
            const SizedBox(height: 12),
            TextField(
                controller: description,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Description')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (save != true || !mounted) return;
    if (name.text.trim().isEmpty) {
      showSnack(context, 'Le nom est obligatoire', isError: true);
      return;
    }
    final service = context.read<DoctorService>();
    final desc = description.text.trim().isEmpty ? null : description.text.trim();
    final ok = await runWithFeedback(
      context,
      () => current == null
          ? service.createSpeciality(name.text.trim(), desc)
          : service.updateSpeciality(current.id, name.text.trim(), desc),
      successMessage: 'Spécialité enregistrée',
    );
    if (ok) setState(() => _key = UniqueKey());
  }

  Future<void> _delete(Speciality s) async {
    final ok = await confirm(context,
        title: 'Supprimer « ${s.name} » ?',
        message: 'Impossible si des médecins y sont rattachés.',
        confirmLabel: 'Supprimer',
        destructive: true);
    if (!ok || !mounted) return;
    final done = await runWithFeedback(context, () => context.read<DoctorService>().deleteSpeciality(s.id),
        successMessage: 'Spécialité supprimée');
    if (done) setState(() => _key = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: 'Ajouter',
        onPressed: () => _edit(),
        child: const Icon(Icons.add),
      ),
      body: AsyncView<List<Speciality>>(
        key: _key,
        load: context.read<DoctorService>().getSpecialities,
        builder: (context, items, reload) => RefreshableList(
          onRefresh: reload,
          itemCount: items.length,
          empty: const EmptyState(icon: Icons.category_outlined, message: 'Aucune spécialité'),
          itemBuilder: (context, i) {
            final s = items[i];
            return Card(
              child: ListTile(
                title: Text(s.name),
                subtitle: s.description == null ? null : Text(s.description!),
                onTap: () => _edit(s),
                trailing: IconButton(
                  tooltip: 'Supprimer',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(s),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------- Médicaments

class _MedicinesTab extends StatefulWidget {
  const _MedicinesTab();

  @override
  State<_MedicinesTab> createState() => _MedicinesTabState();
}

class _MedicinesTabState extends State<_MedicinesTab> {
  Key _key = UniqueKey();
  String _query = '';

  Future<void> _edit([Medicine? current]) async {
    final request = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _MedicineDialog(current: current),
    );
    if (request == null || !mounted) return;
    final service = context.read<MedicineService>();
    final ok = await runWithFeedback(
      context,
      () => current == null ? service.create(request) : service.update(current.id, request),
      successMessage: 'Médicament enregistré',
    );
    if (ok) setState(() => _key = UniqueKey());
  }

  Future<void> _delete(Medicine m) async {
    final ok = await confirm(context,
        title: 'Supprimer ${m.displayName} ?',
        message: 'Impossible s\'il figure sur une ordonnance, un stock ou un carnet.',
        confirmLabel: 'Supprimer',
        destructive: true);
    if (!ok || !mounted) return;
    final done = await runWithFeedback(context, () => context.read<MedicineService>().delete(m.id),
        successMessage: 'Médicament supprimé');
    if (done) setState(() => _key = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: 'Ajouter',
        onPressed: () => _edit(),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Rechercher'),
              onSubmitted: (v) => setState(() {
                _query = v.trim();
                _key = UniqueKey();
              }),
            ),
          ),
          Expanded(
            child: AsyncView<PageResponse<Medicine>>(
              key: _key,
              load: () => context.read<MedicineService>().search(query: _query, size: 100),
              builder: (context, page, reload) => RefreshableList(
                onRefresh: reload,
                itemCount: page.content.length,
                empty: const EmptyState(icon: Icons.medication_outlined, message: 'Aucun médicament'),
                itemBuilder: (context, i) {
                  final m = page.content[i];
                  return Card(
                    child: ListTile(
                      title: Text('${m.name} ${m.strength}'),
                      subtitle: Text('${m.formLabel} · ${m.activeIngredient}'
                          '${m.manufacturer == null ? '' : ' · ${m.manufacturer}'}'),
                      onTap: () => _edit(m),
                      trailing: IconButton(
                        tooltip: 'Supprimer',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _delete(m),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MedicineDialog extends StatefulWidget {
  const _MedicineDialog({this.current});

  final Medicine? current;

  @override
  State<_MedicineDialog> createState() => _MedicineDialogState();
}

class _MedicineDialogState extends State<_MedicineDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.current?.name ?? '');
  late final _ingredient = TextEditingController(text: widget.current?.activeIngredient ?? '');
  late final _strength = TextEditingController(text: widget.current?.strength ?? '');
  late final _manufacturer = TextEditingController(text: widget.current?.manufacturer ?? '');
  late String _form = widget.current?.form ?? 'TABLET';

  @override
  void dispose() {
    for (final c in [_name, _ingredient, _strength, _manufacturer]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 12);
    return AlertDialog(
      title: Text(widget.current == null ? 'Nouveau médicament' : 'Modifier le médicament'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Nom'),
                  validator: Validators.required),
              gap,
              TextFormField(
                  controller: _ingredient,
                  decoration: const InputDecoration(labelText: 'Principe actif'),
                  validator: Validators.required),
              gap,
              TextFormField(
                  controller: _strength,
                  decoration: const InputDecoration(labelText: 'Dosage', hintText: '500 mg'),
                  validator: Validators.required),
              gap,
              DropdownButtonFormField<String>(
                initialValue: _form,
                decoration: const InputDecoration(labelText: 'Forme'),
                items: [
                  for (final e in medicineForms.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => setState(() => _form = v ?? _form),
              ),
              gap,
              TextFormField(
                  controller: _manufacturer,
                  decoration: const InputDecoration(labelText: 'Laboratoire (optionnel)')),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(context, {
              'name': _name.text.trim(),
              'activeIngredient': _ingredient.text.trim(),
              'strength': _strength.text.trim(),
              'form': _form,
              'manufacturer': _manufacturer.text.trim().isEmpty ? null : _manufacturer.text.trim(),
            });
          },
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
