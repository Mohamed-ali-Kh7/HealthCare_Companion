import 'package:flutter/material.dart';

import '../../widgets/doctor_availability.dart';
import '../common/role_scaffold.dart';
import '../messaging/conversations_screen.dart';
import 'availability_screen.dart';
import 'billing_screen.dart';
import 'doctor_ambulance_screen.dart';
import 'doctor_appointments_screen.dart';
import 'doctor_patients_screen.dart';
import 'doctor_profile_screen.dart';
import 'doctor_stats_screen.dart';
import 'issued_prescriptions_screen.dart';

class DoctorHomeScreen extends StatelessWidget {
  const DoctorHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleScaffold(
      onOpenProfile: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DoctorProfileScreen())),
      actions: [
        // Absent / disponible : visible par les patients dans leur messagerie
        const DoctorAvailabilityChip(),
        const MessagesButton(),
        IconButton(
          tooltip: 'Facturation',
          icon: const Icon(Icons.receipt_long_outlined),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BillingScreen())),
        ),
        IconButton(
          tooltip: 'Mes statistiques',
          icon: const Icon(Icons.insights),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DoctorStatsScreen())),
        ),
      ],
      tabs: [
        RoleTab(
          label: 'Planning',
          icon: Icons.calendar_month_outlined,
          selectedIcon: Icons.calendar_month,
          builder: (_) => const DoctorAppointmentsScreen(),
        ),
        RoleTab(
          label: 'Patients',
          icon: Icons.people_outline,
          selectedIcon: Icons.people,
          builder: (_) => const DoctorPatientsScreen(),
        ),
        RoleTab(
          label: 'Ordonnances',
          icon: Icons.receipt_long_outlined,
          selectedIcon: Icons.receipt_long,
          builder: (_) => const IssuedPrescriptionsScreen(),
        ),
        RoleTab(
          label: 'Urgences',
          icon: Icons.local_hospital_outlined,
          selectedIcon: Icons.local_hospital,
          builder: (_) => const DoctorAmbulanceScreen(),
        ),
        RoleTab(
          label: 'Disponibilités',
          icon: Icons.schedule_outlined,
          selectedIcon: Icons.schedule,
          builder: (_) => const AvailabilityScreen(),
        ),
      ],
    );
  }
}
