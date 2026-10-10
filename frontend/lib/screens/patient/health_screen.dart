import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/sensors/sensor_collector.dart';
import '../../core/utils/formatters.dart';
import '../../models/sensor.dart';
import '../../services/telemonitoring_service.dart';
import '../../widgets/async_view.dart';
import '../../widgets/sensor_chart.dart';
import '../../widgets/ui_helpers.dart';

/// Télésuivi côté patient : collecte des capteurs, saisie manuelle, historique 7 jours.
/// Les mêmes données sont visibles par le médecin traitant.
class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  Key _chartsKey = UniqueKey();

  void _refreshCharts() => setState(() => _chartsKey = UniqueKey());

  Future<void> _sync() async {
    final accepted = await context.read<SensorCollector>().sync();
    if (!mounted) return;
    showSnack(context, accepted > 0 ? '$accepted mesure(s) envoyée(s)' : 'Rien de nouveau à envoyer');
    _refreshCharts();
  }

  Future<void> _addHeartRate() async {
    final controller = TextEditingController();
    final value = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fréquence cardiaque'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(suffixText: 'bpm', hintText: 'ex : 72'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: () => Navigator.pop(context, int.tryParse(controller.text)),
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );
    if (value == null || !mounted) return;
    if (value < 20 || value > 250) {
      showSnack(context, 'Valeur hors limites (20 à 250 bpm)', isError: true);
      return;
    }
    final ok = await runWithFeedback(
      context,
      () => context.read<SensorCollector>().addHeartRate(value),
      successMessage: 'Mesure enregistrée',
    );
    if (ok) _refreshCharts();
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<TelemonitoringService>();
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const _CollectorCard(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _sync,
                  icon: const Icon(Icons.sync),
                  label: const Text('Synchroniser'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _addHeartRate,
                  icon: const Icon(Icons.favorite_border),
                  label: const Text('Saisir mon pouls'),
                ),
              ),
            ],
          ),
        ),
        AsyncView<List<List<DailySummary>>>(
          key: _chartsKey,
          load: () => Future.wait([
            service.getMySummary(SensorType.steps),
            service.getMySummary(SensorType.heartRate),
          ]),
          builder: (context, data, _) => Column(
            children: [
              SensorSummaryCard(type: SensorType.steps, data: data[0]),
              SensorSummaryCard(type: SensorType.heartRate, data: data[1]),
            ],
          ),
        ),
      ],
    );
  }
}

class _CollectorCard extends StatelessWidget {
  const _CollectorCard();

  @override
  Widget build(BuildContext context) {
    final collector = context.watch<SensorCollector>();
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sensors, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text('Collecte automatique', style: theme.textTheme.titleMedium)),
                Switch(
                  value: collector.running,
                  onChanged: (on) => on ? collector.start() : collector.stop(),
                ),
              ],
            ),
            Text(
              collector.running
                  ? 'Podomètre et accéléromètre actifs. Envoi toutes les 15 minutes tant que l\'application est ouverte.'
                  : 'Activez la collecte pour transmettre votre activité à votre médecin traitant.',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (collector.running) ...[
              const SizedBox(height: 8),
              Text('Pas en attente d\'envoi : ${collector.pendingSteps ?? 0}'),
              Text('Dernier envoi : ${collector.lastSync == null ? 'jamais' : Fmt.dateTime(collector.lastSync!)}'),
            ],
            if (collector.error != null) ...[
              const SizedBox(height: 8),
              Text(collector.error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
          ],
        ),
      ),
    );
  }
}
