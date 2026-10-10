import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../models/medicine.dart';
import '../../models/pharmacy.dart';
import '../../services/pharmacy_service.dart';
import '../../widgets/async_view.dart';
import '../../widgets/medicine_picker.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/ui_helpers.dart';

/// Mise à jour rapide de l'inventaire : la disponibilité est visible immédiatement par les patients.
class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  Key _viewKey = UniqueKey();
  String _filter = '';

  void _reload() => setState(() => _viewKey = UniqueKey());

  Future<void> _add() async {
    final medicine = await pickMedicine(context);
    if (medicine == null || !mounted) return;
    await _edit(medicine, null);
  }

  Future<void> _edit(Medicine medicine, StockItem? current) async {
    final result = await showDialog<(int, double?)>(
      context: context,
      builder: (_) => _StockDialog(medicine: medicine, current: current),
    );
    if (result == null || !mounted) return;
    final ok = await runWithFeedback(
      context,
      () => context.read<PharmacyService>().upsertStock(
            medicineId: medicine.id,
            quantity: result.$1,
            price: result.$2,
          ),
      successMessage: 'Stock mis à jour',
    );
    if (ok) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Référencer'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              onChanged: (v) => setState(() => _filter = v.trim().toLowerCase()),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.filter_list), hintText: 'Filtrer'),
            ),
          ),
          Expanded(
            child: AsyncView<List<StockItem>>(
              key: _viewKey,
              load: context.read<PharmacyService>().getMyStock,
              builder: (context, stock, reload) {
                final visible = stock
                    .where((s) =>
                        _filter.isEmpty ||
                        s.medicine.name.toLowerCase().contains(_filter) ||
                        s.medicine.activeIngredient.toLowerCase().contains(_filter))
                    .toList();
                return RefreshableList(
                  onRefresh: reload,
                  itemCount: visible.length,
                  empty: const EmptyState(
                    icon: Icons.inventory_2_outlined,
                    message: 'Aucun médicament référencé.\nAjoutez vos produits pour apparaître dans les recherches.',
                  ),
                  itemBuilder: (context, i) {
                    final s = visible[i];
                    final (label, color) = s.quantity == 0
                        ? ('Rupture', Colors.red)
                        : s.quantity < 5
                            ? ('Stock bas', Colors.orange)
                            : ('Disponible', Colors.green);
                    return Card(
                      child: ListTile(
                        title: Text('${s.medicine.name} ${s.medicine.strength}'),
                        subtitle: Text(
                            '${s.medicine.formLabel} · ${Fmt.price(s.price)}\nMàj : ${s.lastUpdated == null ? '—' : Fmt.dateTime(s.lastUpdated!)}'),
                        isThreeLine: true,
                        leading: CircleAvatar(child: Text('${s.quantity}')),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            StatusChip(label: label, color: color),
                          ],
                        ),
                        onTap: () => _edit(s.medicine, s),
                        onLongPress: () async {
                          final ok = await confirm(context,
                              title: 'Retirer du stock ?',
                              message: '${s.medicine.displayName} ne sera plus référencé.',
                              confirmLabel: 'Retirer',
                              destructive: true);
                          if (!ok || !context.mounted) return;
                          final done = await runWithFeedback(
                            context,
                            () => context.read<PharmacyService>().deleteStock(s.id),
                            successMessage: 'Référence retirée',
                          );
                          if (done) await reload();
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StockDialog extends StatefulWidget {
  const _StockDialog({required this.medicine, this.current});

  final Medicine medicine;
  final StockItem? current;

  @override
  State<_StockDialog> createState() => _StockDialogState();
}

class _StockDialogState extends State<_StockDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _quantity = TextEditingController(text: '${widget.current?.quantity ?? 0}');
  late final _price = TextEditingController(text: widget.current?.price?.toStringAsFixed(3) ?? '');

  @override
  void dispose() {
    _quantity.dispose();
    _price.dispose();
    super.dispose();
  }

  void _adjust(int delta) {
    final value = (int.tryParse(_quantity.text) ?? 0) + delta;
    _quantity.text = '${value < 0 ? 0 : value}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.medicine.displayName),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(onPressed: () => _adjust(-1), icon: const Icon(Icons.remove_circle_outline)),
                Expanded(
                  child: TextFormField(
                    controller: _quantity,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Quantité'),
                    validator: (v) => int.tryParse(v ?? '') == null ? 'Quantité invalide' : null,
                  ),
                ),
                IconButton(onPressed: () => _adjust(1), icon: const Icon(Icons.add_circle_outline)),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Prix (TND, optionnel)', hintText: '3.450'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final p = double.tryParse(v.replaceAll(',', '.'));
                return (p == null || p < 0) ? 'Prix invalide' : null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            final price = _price.text.trim().isEmpty ? null : double.parse(_price.text.replaceAll(',', '.'));
            Navigator.pop(context, (int.parse(_quantity.text), price));
          },
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
