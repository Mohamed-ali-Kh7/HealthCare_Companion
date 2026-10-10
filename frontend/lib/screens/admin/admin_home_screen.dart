import 'package:flutter/material.dart';

import '../common/role_scaffold.dart';
import 'admin_appointments_screen.dart';
import 'dashboard_screen.dart';
import 'referentials_screen.dart';
import 'users_screen.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleScaffold(
      tabs: [
        RoleTab(
          label: 'Supervision',
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard,
          builder: (_) => const DashboardScreen(),
        ),
        RoleTab(
          label: 'Comptes',
          icon: Icons.manage_accounts_outlined,
          selectedIcon: Icons.manage_accounts,
          builder: (_) => const UsersScreen(),
        ),
        RoleTab(
          label: 'Référentiels',
          icon: Icons.library_books_outlined,
          selectedIcon: Icons.library_books,
          builder: (_) => const ReferentialsScreen(),
        ),
        RoleTab(
          label: 'Rendez-vous',
          icon: Icons.event_note_outlined,
          selectedIcon: Icons.event_note,
          builder: (_) => const AdminAppointmentsScreen(),
        ),
      ],
    );
  }
}
