import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/appointment.dart';
import '../../services/appointment_service.dart';
import '../../widgets/appointment_card.dart';
import '../../widgets/async_view.dart';
import '../../widgets/ui_helpers.dart';

/// Supervision de tous les rendez-vous de la plateforme (lecture seule).
class AdminAppointmentsScreen extends StatefulWidget {
  const AdminAppointmentsScreen({super.key});

  @override
  State<AdminAppointmentsScreen> createState() => _AdminAppointmentsScreenState();
}

class _AdminAppointmentsScreenState extends State<AdminAppointmentsScreen> {
  AppointmentStatus? _status;
  final List<Appointment> _items = [];
  int _page = 0;
  bool _hasNext = false;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  Future<void> _load({required bool reset}) async {
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _page = 0;
        _items.clear();
      }
    });
    try {
      final result = await context.read<AppointmentService>().getAll(status: _status, page: _page);
      if (!mounted) return;
      setState(() {
        _items.addAll(result.content);
        _hasNext = result.hasNext;
        _page = result.page + 1;
      });
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            children: [
              for (final s in <AppointmentStatus?>[null, ...AppointmentStatus.values])
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(s?.label ?? 'Tous'),
                    selected: _status == s,
                    onSelected: (_) {
                      setState(() => _status = s);
                      _load(reset: true);
                    },
                  ),
                ),
            ],
          ),
        ),
        if (_loading && _items.isEmpty) const LinearProgressIndicator(),
        Expanded(
          child: _error != null && _items.isEmpty
              ? ErrorState(message: _error!, onRetry: () => _load(reset: true))
              : RefreshableList(
                  onRefresh: () => _load(reset: true),
                  itemCount: _items.length + (_hasNext ? 1 : 0),
                  empty: _loading
                      ? const SizedBox.shrink()
                      : const EmptyState(icon: Icons.event_busy, message: 'Aucun rendez-vous'),
                  itemBuilder: (context, i) {
                    if (i == _items.length) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: OutlinedButton(
                          onPressed: _loading ? null : () => _load(reset: false),
                          child: const Text('Charger plus'),
                        ),
                      );
                    }
                    final a = _items[i];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                          child: Text('Patient : ${a.patient.fullName}',
                              style: Theme.of(context).textTheme.labelMedium),
                        ),
                        AppointmentCard(appointment: a),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}
