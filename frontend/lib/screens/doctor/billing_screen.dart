import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/calls/call_service.dart';
import '../../core/utils/formatters.dart';
import '../../models/invoice.dart';
import '../../services/billing_service.dart';
import '../../widgets/async_view.dart';
import '../../widgets/invoice_card.dart';
import '../../widgets/stat_widgets.dart';
import '../../widgets/ui_helpers.dart';

typedef _BillingData = ({BillingSummary summary, List<ToInvoice> toInvoice, List<Invoice> invoices});

/// Médecin (consultations) ou société d'ambulance (transports, [forCompany]) : revenus, prestations terminées
/// à facturer, factures émises (encaissement sur place). [embedded] : affiché dans un onglet, sans barre de titre.
class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key, this.forCompany = false, this.embedded = false});

  final bool forCompany;
  final bool embedded;

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
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

  Future<_BillingData> _load() async {
    final billing = context.read<BillingService>();
    final results = await Future.wait([billing.getSummary(company: widget.forCompany),
      billing.getToInvoice(company: widget.forCompany),
      billing.getIssuedInvoices(company: widget.forCompany),
    ]);
    return (
      summary: results[0] as BillingSummary,
      toInvoice: results[1] as List<ToInvoice>,
      invoices: results[2] as List<Invoice>,
    );
  }

  Future<void> _create(ToInvoice item, int ratePercent, Future<void> Function() reload) async {
    final created = await showModalBottomSheet<Invoice>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => CreateInvoiceSheet(item: item, cnamRatePercent: ratePercent, forCompany: widget.forCompany),
    );
    if (created != null && mounted) {
      showSnack(context, 'Facture ${created.number} envoyée à ${created.patient.fullName}');
      await reload();
    }
  }

  Future<void> _cash(Invoice i, Future<void> Function() reload) async {
    final ok = await confirm(context,
        title: widget.forCompany ? 'Encaissement' : 'Encaissement au cabinet',
        message: '${i.patient.fullName} a réglé ${Fmt.price(i.patientDue)} en espèces ?',
        confirmLabel: 'Marquer payée');
    if (!ok || !mounted) return;
    final done = await runWithFeedback(context, () => context.read<BillingService>().markPaidInCash(i.id, company: widget.forCompany),
        successMessage: 'Facture ${i.number} réglée');
    if (done) await reload();
  }

  @override
  Widget build(BuildContext context) {
    final body = AsyncView<_BillingData>(
        load: _load,
        builder: (context, data, reload) {
          _reload = reload;
          final s = data.summary;
          final title = Theme.of(context).textTheme.titleMedium;
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: StatGrid(children: [
                    StatTile(icon: Icons.today, label: 'Encaissé aujourd\'hui', value: Fmt.price(s.collectedToday)),
                    StatTile(icon: Icons.calendar_month, label: 'Encaissé ce mois', value: Fmt.price(s.collectedThisMonth)),
                    StatTile(
                      icon: Icons.hourglass_bottom,
                      label: '${s.unpaidCount} facture(s) impayée(s)',
                      value: Fmt.price(s.unpaidAmount),
                      highlight: s.unpaidCount > 0,
                    ),
                    StatTile(
                      icon: Icons.account_balance,
                      label: 'Dû par la CNAM (mois)',
                      value: Fmt.price(s.cnamReceivableThisMonth),
                    ),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Text(
                      '${widget.forCompany ? 'Transports' : 'Consultations'} à facturer (${data.toInvoice.length})',
                      style: title),
                ),
                if (data.toInvoice.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Text(widget.forCompany
                        ? 'Tous vos transports terminés sont facturés.'
                        : 'Toutes vos consultations terminées sont facturées.'),
                  ),
                for (final t in data.toInvoice)
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                      title: Text(t.patient.fullName),
                      subtitle: Text('${Fmt.dateTime(t.serviceDate)}${t.reason == null ? '' : ' · ${t.reason}'}'
                          '${t.patient.cnamNumber == null ? '\nSans numéro CNAM' : ''}'),
                      isThreeLine: t.patient.cnamNumber == null,
                      trailing: FilledButton(
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                        onPressed: () => _create(t, s.cnamRatePercent, reload),
                        child: const Text('Facturer'),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                  child: Text('Factures émises (${data.invoices.length})', style: title),
                ),
                if (data.invoices.isEmpty)
                  const Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, 8), child: Text('Aucune facture.')),
                for (final i in data.invoices)
                  InvoiceCard(
                    invoice: i,
                    forDoctor: true,
                    actions: [
                      if (!i.isPaid)
                        OutlinedButton.icon(
                          icon: const Icon(Icons.payments_outlined, size: 18),
                          label: const Text('Payée en espèces'),
                          onPressed: () => _cash(i, reload),
                        ),
                    ],
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Text(
                    'Prise en charge CNAM simulée (taux ${s.cnamRatePercent} %) et paiement en ligne simulé : '
                    'aucune connexion réelle à la CNAM ni à une banque.',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          );
        },
      );
    if (widget.embedded) return body;
    return Scaffold(appBar: AppBar(title: const Text('Facturation')), body: body);
  }
}

/// Saisie de la facture : acte, montant, prise en charge CNAM, avec le calcul en direct.
class CreateInvoiceSheet extends StatefulWidget {
  const CreateInvoiceSheet({super.key, required this.item, required this.cnamRatePercent, this.forCompany = false});

  final ToInvoice item;
  final int cnamRatePercent;

  /// Transport (actes ambulance / VSL) au lieu d'une consultation.
  final bool forCompany;

  @override
  State<CreateInvoiceSheet> createState() => _CreateInvoiceSheetState();
}

class _CreateInvoiceSheetState extends State<CreateInvoiceSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _amount = TextEditingController(text: widget.item.suggestedFee.toStringAsFixed(3));
  late String _act = widget.item.suggestedAct;
  late CnamCoverage _coverage =
      widget.item.patient.cnamNumber == null ? CnamCoverage.none : CnamCoverage.reimbursement;
  List<CareActOption> _acts = const [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    context.read<BillingService>().getActs().then((acts) {
      // Le médecin ne voit que les consultations, la société que les transports
      final transport = {'AMBULANCE_TRANSPORT', 'VSL_TRANSPORT'};
      if (mounted) {
        setState(() => _acts = acts.where((a) => transport.contains(a.code) == widget.forCompany).toList());
      }
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  double? get _amountValue => double.tryParse(_amount.text.replaceAll(',', '.'));

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final invoice = await context.read<BillingService>().create(
            appointmentId: widget.item.appointmentId,
            ambulanceRequestId: widget.item.ambulanceRequestId,
            act: _act,
            amount: _amountValue!,
            coverage: _coverage,
          );
      if (mounted) Navigator.of(context).pop(invoice);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showSnack(context, errorMessage(e), isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.item.patient;
    final hasCnam = p.cnamNumber != null;
    final amount = _amountValue ?? 0;
    final rate = _coverage == CnamCoverage.none ? 0 : widget.cnamRatePercent;
    final cnamShare = amount * rate / 100;
    final patientDue = _coverage == CnamCoverage.privateSector ? amount - cnamShare : amount;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(widget.forCompany ? 'Facturer le transport' : 'Facturer la consultation',
                style: Theme.of(context).textTheme.titleLarge),
            Text('${p.fullName} · ${Fmt.dateTime(widget.item.serviceDate)}',
                style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _act,
              decoration: const InputDecoration(labelText: 'Acte'),
              items: [
                for (final a in _acts) DropdownMenuItem(value: a.code, child: Text(a.label)),
                if (_acts.every((a) => a.code != _act)) DropdownMenuItem(value: _act, child: Text(_act)),
              ],
              onChanged: (v) {
                if (v == null) return;
                final fee = _acts.where((a) => a.code == v).firstOrNull?.suggestedFee;
                setState(() {
                  _act = v;
                  if (fee != null) _amount.text = fee.toStringAsFixed(3);
                });
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Honoraires', suffixText: 'TND'),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                final value = double.tryParse((v ?? '').replaceAll(',', '.'));
                if (value == null) return 'Montant invalide';
                if (value < 1 || value > 2000) return 'Entre 1 et 2 000 TND';
                return null;
              },
            ),
            const SizedBox(height: 16),
            Text('Prise en charge CNAM', style: Theme.of(context).textTheme.titleSmall),
            if (!hasCnam)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Le patient n\'a pas renseigné son numéro CNAM dans son profil.',
                    style: TextStyle(color: scheme.error, fontSize: 12.5)),
              ),
            RadioGroup<CnamCoverage>(
              groupValue: _coverage,
              onChanged: (v) => setState(() => _coverage = v ?? _coverage),
              child: Column(children: [
                for (final c in CnamCoverage.values)
                  RadioListTile<CnamCoverage>(
                    value: c,
                    enabled: c == CnamCoverage.none || hasCnam,
                    contentPadding: EdgeInsets.zero,
                    title: Text(c.label),
                    subtitle: Text(c.help, style: const TextStyle(fontSize: 12)),
                  ),
              ]),
            ),
            Card(
              margin: const EdgeInsets.only(top: 8),
              color: scheme.surfaceContainerHigh,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  _row('Honoraires', Fmt.price(amount)),
                  if (rate > 0) _row('Part CNAM ($rate %)', Fmt.price(cnamShare)),
                  const Divider(),
                  _row('Le patient paie', Fmt.price(patientDue), bold: true),
                  if (_coverage == CnamCoverage.reimbursement)
                    _row('Il sera remboursé de', Fmt.price(cnamShare)),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: const Icon(Icons.send),
              label: Text(_saving ? 'Envoi…' : 'Émettre la facture'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    final style = TextStyle(fontWeight: bold ? FontWeight.w700 : null);
    return Row(children: [Expanded(child: Text(label, style: style)), Text(value, style: style)]);
  }
}
