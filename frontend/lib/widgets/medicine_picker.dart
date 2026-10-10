import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/medicine.dart';
import '../services/medicine_service.dart';
import 'ui_helpers.dart';

/// Ouvre une recherche dans le référentiel et renvoie le médicament choisi.
Future<Medicine?> pickMedicine(BuildContext context) {
  return showModalBottomSheet<Medicine>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _MedicinePickerSheet(),
  );
}

class _MedicinePickerSheet extends StatefulWidget {
  const _MedicinePickerSheet();

  @override
  State<_MedicinePickerSheet> createState() => _MedicinePickerSheetState();
}

class _MedicinePickerSheetState extends State<_MedicinePickerSheet> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<Medicine> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _search(''));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value));
  }

  Future<void> _search(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await context.read<MedicineService>().search(query: query.trim(), size: 30);
      if (!mounted) return;
      setState(() => _results = page.content);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _onChanged,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Nom ou principe actif',
                ),
              ),
            ),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null) Padding(padding: const EdgeInsets.all(16), child: Text(_error!)),
            Expanded(
              child: ListView.separated(
                itemCount: _results.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final m = _results[i];
                  return ListTile(
                    leading: const Icon(Icons.medication_outlined),
                    title: Text('${m.name} ${m.strength}'),
                    subtitle: Text('${m.formLabel} · ${m.activeIngredient}'),
                    onTap: () => Navigator.pop(context, m),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
