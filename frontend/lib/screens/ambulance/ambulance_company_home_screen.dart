import 'package:flutter/material.dart';

import '../common/role_scaffold.dart';
import '../doctor/billing_screen.dart';
import 'company_profile_screen.dart';
import 'fleet_screen.dart';
import 'missions_screen.dart';

/// Espace d'une société d'ambulance conventionnée CNAM.
class AmbulanceCompanyHomeScreen extends StatelessWidget {
  const AmbulanceCompanyHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleScaffold(
      tabs: [
        RoleTab(
          label: 'Missions',
          icon: Icons.assignment_outlined,
          selectedIcon: Icons.assignment,
          builder: (_) => const MissionsScreen(),
        ),
        RoleTab(
          label: 'Flotte',
          icon: Icons.airport_shuttle_outlined,
          selectedIcon: Icons.airport_shuttle,
          builder: (_) => const FleetScreen(),
        ),
        RoleTab(
          label: 'Facturation',
          icon: Icons.receipt_long_outlined,
          selectedIcon: Icons.receipt_long,
          builder: (_) => const BillingScreen(forCompany: true, embedded: true),
        ),
        RoleTab(
          label: 'Ma société',
          icon: Icons.business_outlined,
          selectedIcon: Icons.business,
          builder: (_) => const CompanyProfileScreen(),
        ),
      ],
    );
  }
}
