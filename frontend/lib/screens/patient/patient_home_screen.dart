import 'package:flutter/material.dart';

import '../common/role_scaffold.dart';
import 'doctors_screen.dart';
import 'health_screen.dart';
import 'my_appointments_screen.dart';
import 'patient_profile_screen.dart';
import 'pharmacies_screen.dart';
import 'treatments_screen.dart';

class PatientHomeScreen extends StatelessWidget {
  const PatientHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleScaffold(
      onOpenProfile: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const PatientProfileScreen())),
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
