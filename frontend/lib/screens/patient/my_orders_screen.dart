import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/calls/call_service.dart';
import '../../models/order.dart';
import '../../services/order_service.dart';
import '../../widgets/async_view.dart';
import '../../widgets/order_card.dart';
import '../../widgets/ui_helpers.dart';

/// Patient : ses réservations et commandes de médicaments, mises à jour en direct.
class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
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

  Future<void> _cancel(MedicineOrder o, Future<void> Function() reload) async {
    final ok = await confirm(context,
        title: o.isDelivery ? 'Annuler la commande ?' : 'Annuler la réservation ?',
        message: '${o.quantity} × ${o.medicine.name} chez ${o.pharmacy.name}',
        confirmLabel: 'Annuler',
        destructive: true);
    if (!ok || !mounted) return;
    final done =
        await runWithFeedback(context, () => context.read<OrderService>().cancel(o.id), successMessage: 'Annulée');
    if (done) await reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes commandes')),
      body: AsyncView<List<MedicineOrder>>(
        load: () => context.read<OrderService>().getMine(),
        builder: (context, orders, reload) {
          _reload = reload;
          return RefreshableList(
            onRefresh: reload,
            itemCount: orders.length,
            empty: const EmptyState(
              icon: Icons.shopping_bag_outlined,
              message: 'Aucune commande.\nCherchez un médicament puis « Réserver » ou « Commander ».',
            ),
            itemBuilder: (context, i) {
              final o = orders[i];
              return OrderCard(
                order: o,
                actions: [
                  if (o.isOpen) TextButton(onPressed: () => _cancel(o, reload), child: const Text('Annuler')),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
