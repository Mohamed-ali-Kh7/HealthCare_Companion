import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/calls/call_service.dart';
import '../../core/utils/formatters.dart';
import '../../models/invoice.dart';
import '../../services/billing_service.dart';
import '../../widgets/async_view.dart';
import '../../widgets/invoice_card.dart';
import '../../widgets/ui_helpers.dart';

/// Patient : ses factures, paiement en ligne (simulé), facture et bulletin de soins en PDF.
class MyInvoicesScreen extends StatefulWidget {
  const MyInvoicesScreen({super.key});

  @override
  State<MyInvoicesScreen> createState() => _MyInvoicesScreenState();
}

class _MyInvoicesScreenState extends State<MyInvoicesScreen> {
  Future<void> Function()? _reload;
  StreamSubscription<Invoice>? _live;

  @override
  void initState() {
    super.initState();
    _live = context.read<CallService>().invoiceUpdates.listen((_) => _reload?.call());
  }

  @override
  void dispose() {
    _live?.cancel();
    super.dispose();
  }

  Future<void> _pay(Invoice invoice, Future<void> Function() reload) async {
    final paid = await showModalBottomSheet<Invoice>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PaymentSheet(invoice: invoice),
    );
    if (paid != null && mounted) {
      showSnack(context, 'Paiement accepté : ${Fmt.price(paid.patientDue)}');
      await reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes factures')),
      body: AsyncView<List<Invoice>>(
        load: () => context.read<BillingService>().getMine(),
        builder: (context, invoices, reload) {
          _reload = reload;
          final due = invoices.where((i) => !i.isPaid).fold<double>(0, (s, i) => s + i.patientDue);
          return RefreshableList(
            onRefresh: reload,
            itemCount: invoices.length,
            header: invoices.isEmpty
                ? null
                : Card(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                    color: due > 0
                        ? Theme.of(context).colorScheme.tertiaryContainer
                        : Theme.of(context).colorScheme.secondaryContainer,
                    child: ListTile(
                      leading: Icon(due > 0 ? Icons.account_balance_wallet_outlined : Icons.check_circle_outline),
                      title: Text(due > 0 ? 'Reste à payer : ${Fmt.price(due)}' : 'Toutes vos factures sont réglées'),
                      subtitle: const Text('Paiement en ligne simulé · prise en charge CNAM simulée'),
                    ),
                  ),
            empty: const EmptyState(
              icon: Icons.receipt_long_outlined,
              message: 'Aucune facture.\nVos consultations facturées par vos médecins apparaîtront ici.',
            ),
            itemBuilder: (context, index) {
              final i = invoices[index];
              return InvoiceCard(
                invoice: i,
                forDoctor: false,
                actions: [
                  if (!i.isPaid)
                    FilledButton.icon(
                      icon: const Icon(Icons.credit_card, size: 18),
                      label: Text('Payer ${Fmt.price(i.patientDue)}'),
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                      onPressed: () => _pay(i, reload),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// Formulaire de carte bancaire. Simulé : aucune somme n'est débitée, la carte n'est pas enregistrée.
class PaymentSheet extends StatefulWidget {
  const PaymentSheet({super.key, required this.invoice});

  final Invoice invoice;

  @override
  State<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<PaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _holder = TextEditingController(text: widget.invoice.patient.fullName);
  final _number = TextEditingController();
  final _expiry = TextEditingController();
  final _cvv = TextEditingController();
  bool _paying = false;
  String? _error;

  @override
  void dispose() {
    _holder.dispose();
    _number.dispose();
    _expiry.dispose();
    _cvv.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _paying = true;
      _error = null;
    });
    try {
      final paid = await context.read<BillingService>().pay(
            widget.invoice.id,
            holder: _holder.text.trim(),
            cardNumber: _number.text.replaceAll(' ', ''),
            expiry: _expiry.text.trim(),
            cvv: _cvv.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(paid);
    } catch (e) {
      if (mounted) {
        setState(() {
          _paying = false;
          _error = errorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.invoice;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text('Paiement de la facture', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('${i.issuer.name} · ${i.actLabel} · ${i.number}', style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              color: scheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  const Expanded(child: Text('Montant à payer')),
                  Text(Fmt.price(i.patientDue), style: Theme.of(context).textTheme.titleLarge),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _holder,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Titulaire de la carte', prefixIcon: Icon(Icons.person_outline)),
              validator: (v) => v == null || v.trim().isEmpty ? 'Obligatoire' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _number,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, _CardNumberFormatter()],
              decoration: const InputDecoration(
                labelText: 'Numéro de carte',
                hintText: '4242 4242 4242 4242',
                prefixIcon: Icon(Icons.credit_card),
              ),
              validator: (v) {
                final digits = (v ?? '').replaceAll(' ', '');
                return digits.length < 13 ? 'Numéro incomplet' : null;
              },
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _expiry,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, _ExpiryFormatter()],
                  decoration: const InputDecoration(labelText: 'Expiration', hintText: 'MM/AA'),
                  validator: (v) => RegExp(r'^(0[1-9]|1[0-2])/\d{2}$').hasMatch(v ?? '') ? null : 'MM/AA',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _cvv,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 3,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'CVV', counterText: ''),
                  validator: (v) => (v ?? '').length == 3 ? null : '3 chiffres',
                ),
              ),
            ]),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  Icon(Icons.error_outline, color: scheme.onErrorContainer),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_error!, style: TextStyle(color: scheme.onErrorContainer))),
                ]),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _paying ? null : _submit,
              icon: _paying
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.lock_outline),
              label: Text(_paying ? 'Paiement en cours…' : 'Payer ${Fmt.price(i.patientDue)}'),
            ),
            const SizedBox(height: 10),
            Text(
              '🔒 Paiement simulé : aucune somme n\'est débitée et la carte n\'est pas enregistrée.\n'
              'Cartes de test : 4242 4242 4242 4242 (acceptée) · 4000 0000 0000 0002 (refusée) · '
              '4000 0000 0000 9995 (solde insuffisant).',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// « 4242424242424242 » → « 4242 4242 4242 4242 »
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(' ', '');
    final limited = digits.length > 19 ? digits.substring(0, 19) : digits;
    final buffer = StringBuffer();
    for (var k = 0; k < limited.length; k++) {
      if (k > 0 && k % 4 == 0) buffer.write(' ');
      buffer.write(limited[k]);
    }
    final text = buffer.toString();
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

/// « 1230 » → « 12/30 »
class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll('/', '');
    final limited = digits.length > 4 ? digits.substring(0, 4) : digits;
    final text = limited.length > 2 ? '${limited.substring(0, 2)}/${limited.substring(2)}' : limited;
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
