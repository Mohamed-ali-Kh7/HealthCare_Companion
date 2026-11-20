import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/notifications/appointment_reminder_plan.dart';
import '../../core/notifications/appointment_reminder_service.dart';
import '../../core/notifications/reminder_service.dart';
import '../../models/user.dart';
import '../../core/sensors/sensor_collector.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/ui_helpers.dart';
import 'change_password_screen.dart';

/// Onglet d'un espace utilisateur.
class RoleTab {
  const RoleTab({
    required this.label,
    required this.icon,
    required this.builder,
    this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData? selectedIcon;
  final WidgetBuilder builder;
}

/// Squelette commun aux 4 espaces (patient, médecin, pharmacien, admin) :
/// barre de navigation basse + menu compte (profil, mot de passe, déconnexion).
class RoleScaffold extends StatefulWidget {
  const RoleScaffold({super.key, required this.tabs, this.onOpenProfile, this.actions = const []});

  final List<RoleTab> tabs;
  final VoidCallback? onOpenProfile;

  /// Boutons de la barre du haut, visibles quel que soit l'onglet (ex : urgence du patient).
  final List<Widget> actions;

  @override
  State<RoleScaffold> createState() => _RoleScaffoldState();
}

class _RoleScaffoldState extends State<RoleScaffold> {
  int _index = 0;

  /// Onglets déjà ouverts : un onglet n'est construit (et ne charge ses données) qu'à sa première visite.
  final Set<int> _visited = {0};

  StreamSubscription<AppointmentReminder>? _appointmentReminders;
  AppointmentReminderService? _reminderService;

  @override
  void initState() {
    super.initState();
    // Rappels de rendez-vous : patient (ses RDV) et médecin (ses consultations)
    final role = context.read<AuthProvider>().user?.role;
    if (role == UserRole.patient || role == UserRole.doctor) {
      final reminders = _reminderService = context.read<AppointmentReminderService>();
      _appointmentReminders = reminders.due.listen(_showAppointmentReminder);
      unawaited(reminders.start(forDoctor: role == UserRole.doctor));
    }
  }

  @override
  void dispose() {
    _appointmentReminders?.cancel();
    _reminderService?.stop();
    super.dispose();
  }

  /// Bannière en haut de l'écran, jusqu'à ce que l'utilisateur la ferme.
  void _showAppointmentReminder(AppointmentReminder r) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final soon = r.kind == AppointmentReminderKind.oneHourBefore;
    messenger
      ..clearMaterialBanners()
      ..showMaterialBanner(MaterialBanner(
        leading: Icon(soon ? Icons.alarm : Icons.event_available,
            color: soon ? Colors.deepOrange : Theme.of(context).colorScheme.primary),
        content: Text.rich(TextSpan(children: [
          TextSpan(text: '${r.title}\n', style: const TextStyle(fontWeight: FontWeight.bold)),
          TextSpan(text: r.body),
        ])),
        actions: [
          TextButton(onPressed: messenger.clearMaterialBanners, child: const Text('OK')),
        ],
      ));
  }

  Future<void> _logout() async {
    final ok = await confirm(context,
        title: 'Déconnexion', message: 'Voulez-vous vous déconnecter ?', confirmLabel: 'Se déconnecter');
    if (!ok || !mounted) return;
    // Lus avant tout await : la déconnexion ne dépend plus du cycle de vie de l'écran
    final sensors = context.read<SensorCollector>();
    final reminders = context.read<ReminderService>();
    final auth = context.read<AuthProvider>();
    // Le nettoyage est au mieux : un échec (capteur, notifications) ne doit jamais bloquer la déconnexion
    try {
      await sensors.stop();
    } catch (e) {
      debugPrint('Arrêt des capteurs impossible : $e');
    }
    try {
      await reminders.cancelAll();
    } catch (e) {
      debugPrint('Annulation des rappels impossible : $e');
    }
    await auth.logout();
  }

  @override
  Widget build(BuildContext context) {
    final tab = widget.tabs[_index];
    final email = context.watch<AuthProvider>().user?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(tab.label),
        actions: [
          ...widget.actions,
          PopupMenuButton<String>(
            tooltip: 'Mon compte',
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  widget.onOpenProfile?.call();
                case 'password':
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChangePasswordScreen()));
                case 'logout':
                  _logout();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(enabled: false, child: Text(email)),
              if (widget.onOpenProfile != null)
                const PopupMenuItem(
                    value: 'profile', child: ListTile(leading: Icon(Icons.badge_outlined), title: Text('Mon profil'))),
              const PopupMenuItem(
                  value: 'password', child: ListTile(leading: Icon(Icons.key_outlined), title: Text('Mot de passe'))),
              const PopupMenuItem(
                  value: 'logout', child: ListTile(leading: Icon(Icons.logout), title: Text('Déconnexion'))),
            ],
          ),
        ],
      ),
      // IndexedStack : chaque onglet garde son état (défilement, filtres) quand on change d'onglet
      body: IndexedStack(
        index: _index,
        children: [
          for (var i = 0; i < widget.tabs.length; i++)
            _visited.contains(i) ? Builder(builder: widget.tabs[i].builder) : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: widget.tabs.length < 2
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() {
                _index = i;
                _visited.add(i);
              }),
              destinations: [
                for (final t in widget.tabs)
                  NavigationDestination(
                    icon: Icon(t.icon),
                    selectedIcon: Icon(t.selectedIcon ?? t.icon),
                    label: t.label,
                  ),
              ],
            ),
    );
  }
}
