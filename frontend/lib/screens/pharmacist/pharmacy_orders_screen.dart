import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/calls/call_service.dart';
import '../../models/order.dart';
import '../../services/order_service.dart';
import '../../widgets/async_view.dart';
import '../../widgets/order_card.dart';
import '../../widgets/ui_helpers.dart';

/// Pharmacien : réservations et commandes reçues, à confirmer / refuser / remettre.
/// La liste se met à jour seule à chaque nouvelle commande ou annulation.
class PharmacyOrdersScreen extends StatefulWidget {
  const PharmacyOrdersScreen({super.key});

  @override
  State<PharmacyOrdersScreen> createState() => _PharmacyOrdersScreenState();
}

class _PharmacyOrdersScreenState extends State<PharmacyOrdersScreen> {
  Future<void> Function()? _reload;
  StreamSubscription<MedicineOrder>? _live;

  @override
  void initState() {
    super.initState();
    _live = context.read<CallService>().orderUpdates.listen((_) => _reload?.call());
  }

  @override
  void dispose() {
    _live?.cancel();
    super.dispose();
  }

  Future<List<MedicineOrder>> _load() async {
    final orders = await context.read<OrderService>().getForPharmacy();
    // À traiter d'abord, puis en cours, puis l'historique
    int rank(MedicineOrder o) => switch (o.status) {
          OrderStatus.pending => 0,
          OrderStatus.confirmed => 1,
          _ => 2,
        };
    return [...orders]..sort((a, b) {
        final byRank = rank(a).compareTo(rank(b));
        return byRank != 0 ? byRank : b.createdAt.compareTo(a.createdAt);
      });
  }

  Future<void> _act(Future<Object?> Function() action, String success, Future<void> Function() reload) async {
    final ok = await runWithFeedback(context, action, successMessage: success);
    if (ok) await reload();
  }

  List<Widget> _actionsFor(MedicineOrder o, Future<void> Function() reload) {
    final service = context.read<OrderService>();
    switch (o.status) {
      case OrderStatus.pending:
        return [
          TextButton(
            onPressed: () async {
              final note = await promptText(context,
                  title: 'Motif du refus', hint: 'Optionnel (ex : rupture)', confirmLabel: 'Refuser');
              if (note == null || !mounted) return;
              await _act(() => service.reject(o.id, note: note.isEmpty ? null : note), 'Commande refusée', reload);
            },
            child: const Text('Refuser'),
          ),
          FilledButton(
            onPressed: () async {
              final note = await promptText(context,
                  title: o.isDelivery ? 'Confirmer la commande' : 'Confirmer la réservation',
                  hint:
                      o.isDelivery ? 'Optionnel (ex : livraison avant 18 h)' : 'Optionnel (ex : à retirer avant 19 h)',
                  confirmLabel: 'Confirmer');
              if (note == null || !mounted) return;
              await _act(() => service.confirm(o.id, note: note.isEmpty ? null : note), 'Confirmée : stock mis à jour',
                  reload);
            },
            child: const Text('Confirmer'),
          ),
        ];
      case OrderStatus.confirmed:
        return [
          FilledButton.tonal(
            onPressed: () => _act(
                () => service.complete(o.id), o.isDelivery ? 'Livraison enregistrée' : 'Retrait enregistré', reload),
            child: Text(o.isDelivery ? 'Livrée' : 'Retirée par le patient'),
          ),
        ];
      default:
        return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return AsyncView<List<MedicineOrder>>(
      load: _load,
      builder: (context, orders, reload) {
        _reload = reload;
        return RefreshableList(
          onRefresh: reload,
          itemCount: orders.length,
          empty: const EmptyState(icon: Icons.receipt_long_outlined, message: 'Aucune réservation ni commande'),
          itemBuilder: (context, i) => OrderCard(
            order: orders[i],
            forPharmacist: true,
            actions: _actionsFor(orders[i], reload),
          ),
        );
      },
    );
  }
}
