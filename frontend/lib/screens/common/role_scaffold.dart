import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/notifications/reminder_service.dart';
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
  const RoleScaffold({super.key, required this.tabs, this.onOpenProfile});

  final List<RoleTab> tabs;
  final VoidCallback? onOpenProfile;

  @override
  State<RoleScaffold> createState() => _RoleScaffoldState();
}

class _RoleScaffoldState extends State<RoleScaffold> {
  int _index = 0;

  /// Onglets déjà ouverts : un onglet n'est construit (et ne charge ses données) qu'à sa première visite.
  final Set<int> _visited = {0};

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
          PopupMenuButton<String>(
            tooltip: 'Mon compte',
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  widget.onOpenProfile?.call();
                case 'password':
                  Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const ChangePasswordScreen()));
                case 'logout':
                  _logout();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(enabled: false, child: Text(email)),
              if (widget.onOpenProfile != null)
                const PopupMenuItem(
                    value: 'profile',
                    child: ListTile(leading: Icon(Icons.badge_outlined), title: Text('Mon profil'))),
              const PopupMenuItem(
                  value: 'password',
                  child: ListTile(leading: Icon(Icons.key_outlined), title: Text('Mot de passe'))),
              const PopupMenuItem(
                  value: 'logout',
                  child: ListTile(leading: Icon(Icons.logout), title: Text('Déconnexion'))),
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
