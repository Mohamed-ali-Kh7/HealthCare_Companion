import 'package:flutter/material.dart';

import '../common/role_scaffold.dart';
import '../messaging/conversations_screen.dart';
import 'assistant_screen.dart';
import 'doctors_screen.dart';
import 'emergency_screen.dart';
import 'health_screen.dart';
import 'my_appointments_screen.dart';
import 'my_invoices_screen.dart';
import 'my_orders_screen.dart';
import 'patient_profile_screen.dart';
import 'patient_stats_screen.dart';
import 'pharmacies_screen.dart';
import 'treatments_screen.dart';

class PatientHomeScreen extends StatelessWidget {
  const PatientHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleScaffold(
      onOpenProfile: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PatientProfileScreen())),
      // Accessibles depuis n'importe quel onglet, en un geste
      actions: [
        IconButton(
          tooltip: 'Assistant santé 24 h/24',
          icon: const Icon(Icons.smart_toy_outlined),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AssistantScreen())),
        ),
        const MessagesButton(),
        IconButton(
          tooltip: 'Mes commandes',
          icon: const Icon(Icons.shopping_bag_outlined),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyOrdersScreen())),
        ),
        IconButton(
          tooltip: 'Mes factures',
          icon: const Icon(Icons.receipt_long_outlined),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyInvoicesScreen())),
        ),
        IconButton(
          tooltip: 'Mes statistiques',
          icon: const Icon(Icons.insights),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PatientStatsScreen())),
        ),
        IconButton(
          tooltip: 'Urgence',
          icon: Icon(Icons.emergency, color: Theme.of(context).colorScheme.error),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('Urgence')),
              body: const EmergencyScreen(),
            ),
          )),
        ),
      ],
      tabs: [
        RoleTab(
          label: 'Médecins',
          icon: Icons.search,
          builder: (_) => const DoctorsScreen(),
        ),
        RoleTab(
          label: 'Rendez-vous',
          icon: Icons.event_outlined,
          selectedIcon: Icons.event,
          builder: (_) => const MyAppointmentsScreen(),
        ),
        RoleTab(
          label: 'Traitements',
          icon: Icons.medication_outlined,
          selectedIcon: Icons.medication,
          builder: (_) => const TreatmentsScreen(),
        ),
        RoleTab(
          label: 'Pharmacies',
          icon: Icons.local_pharmacy_outlined,
          selectedIcon: Icons.local_pharmacy,
          builder: (_) => const PharmaciesScreen(),
        ),
        RoleTab(
          label: 'Santé',
          icon: Icons.monitor_heart_outlined,
          selectedIcon: Icons.monitor_heart,
          builder: (_) => const HealthScreen(),
        ),
      ],
    );
  }
}
