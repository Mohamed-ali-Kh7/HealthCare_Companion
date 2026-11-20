import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../models/medicine.dart';
import '../../models/order.dart';
import '../../models/pharmacy.dart';
import '../../services/order_service.dart';
import '../../services/patient_service.dart';
import '../../widgets/ui_helpers.dart';

/// Réserver un médicament (retrait en pharmacie) ou le commander en ligne (livraison).
/// Renvoie true (Navigator.pop) quand la demande a été envoyée.
class OrderFormScreen extends StatefulWidget {
  const OrderFormScreen({
    super.key,
    required this.medicine,
    required this.availability,
    required this.initialType,
  });

  final Medicine medicine;
  final MedicineAvailability availability;
  final OrderType initialType;

  @override
  State<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends State<OrderFormScreen> {
  static const _maxPerOrder = 10;

  final _formKey = GlobalKey<FormState>();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _note = TextEditingController();
  late OrderType _type = widget.initialType;
  int _quantity = 1;
  bool _sending = false;

  int get _maxQuantity => widget.availability.quantity < _maxPerOrder ? widget.availability.quantity : _maxPerOrder;

  @override
  void initState() {
    super.initState();
    // Téléphone du profil pré-rempli (modifiable)
    context.read<PatientService>().getMyProfile().then((p) {
      if (mounted && _phone.text.isEmpty && p.phone != null) _phone.text = p.phone!;
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _address.dispose();
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    final delivery = _type == OrderType.delivery;
    final ok = await runWithFeedback(
      context,
      () => context.read<OrderService>().create(
            type: _type,
            pharmacyId: widget.availability.pharmacy.id,
            medicineId: widget.medicine.id,
            quantity: _quantity,
            deliveryAddress: delivery ? _address.text.trim() : null,
            phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          ),
      successMessage: delivery
          ? 'Commande envoyée à ${widget.availability.pharmacy.name}'
          : 'Réservation envoyée à ${widget.availability.pharmacy.name}',
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.availability;
    final delivery = _type == OrderType.delivery;
    final total = a.price == null ? null : a.price! * _quantity;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(delivery ? 'Commander en ligne' : 'Réserver')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<OrderType>(
              segments: [
                for (final t in OrderType.values) ButtonSegment(value: t, icon: Icon(t.icon), label: Text(t.label)),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 8),
            Text(
              delivery
                  ? 'Livré à votre adresse par la pharmacie. Paiement à la livraison.'
                  : 'La pharmacie met le médicament de côté. Vous le retirez et le payez sur place.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.medication),
                title: Text('${widget.medicine.name} ${widget.medicine.strength}'),
                subtitle: Text('${widget.medicine.formLabel}\n${a.pharmacy.name} · ${a.pharmacy.address}'),
                isThreeLine: true,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(child: Text('Quantité', style: TextStyle(fontSize: 16))),
                IconButton.outlined(
                  onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                  icon: const Icon(Icons.remove),
                ),
                SizedBox(
                  width: 44,
                  child: Text('$_quantity', textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
                ),
                IconButton.outlined(
                  onPressed: _quantity < _maxQuantity ? () => setState(() => _quantity++) : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            Text('${a.quantity} en stock · $_maxPerOrder maximum par commande', style: theme.textTheme.bodySmall),
            const SizedBox(height: 16),
            if (delivery) ...[
              TextFormField(
                controller: _address,
                decoration: const InputDecoration(
                  labelText: 'Adresse de livraison',
                  prefixIcon: Icon(Icons.home_outlined),
                ),
                maxLength: 255,
                validator: Validators.required,
              ),
              const SizedBox(height: 8),
            ],
            TextFormField(
              controller: _phone,
              decoration: InputDecoration(
                labelText: delivery ? 'Téléphone (pour le livreur)' : 'Téléphone (optionnel)',
                prefixIcon: const Icon(Icons.phone_outlined),
              ),
              keyboardType: TextInputType.phone,
              maxLength: 30,
              validator: (v) => delivery ? (Validators.required(v) ?? Validators.phone(v)) : Validators.phone(v),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _note,
              decoration: const InputDecoration(
                labelText: 'Note pour la pharmacie (optionnel)',
                prefixIcon: Icon(Icons.notes),
              ),
              maxLength: 500,
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            Card(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text('Total estimé', style: TextStyle(fontSize: 16)),
                    const Spacer(),
                    Text(total == null ? 'Prix en pharmacie' : Fmt.price(total), style: theme.textTheme.titleLarge),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: _sending ? null : _submit,
              icon: _sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(_type.icon),
              label: Text(delivery ? 'Envoyer la commande' : 'Envoyer la réservation'),
            ),
            const SizedBox(height: 8),
            Text(
              'La pharmacie doit confirmer votre demande. Vous serez prévenu dans l\'application.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
