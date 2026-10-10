import 'package:flutter/material.dart';

import '../common/role_scaffold.dart';
import 'availability_screen.dart';
import 'doctor_appointments_screen.dart';
import 'doctor_patients_screen.dart';
import 'doctor_profile_screen.dart';
import 'issued_prescriptions_screen.dart';

class DoctorHomeScreen extends StatelessWidget {
  const DoctorHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleScaffold(
      onOpenProfile: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const DoctorProfileScreen())),
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
          label: 'Disponibilités',
          icon: Icons.schedule_outlined,
          selectedIcon: Icons.schedule,
          builder: (_) => const AvailabilityScreen(),
        ),
      ],
    );
  }
}
