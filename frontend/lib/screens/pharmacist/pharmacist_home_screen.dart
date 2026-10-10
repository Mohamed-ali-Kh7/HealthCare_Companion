import 'package:flutter/material.dart';

import '../common/role_scaffold.dart';
import 'pharmacy_profile_screen.dart';
import 'stock_screen.dart';

class PharmacistHomeScreen extends StatelessWidget {
  const PharmacistHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleScaffold(
      tabs: [
        RoleTab(
          label: 'Stock',
          icon: Icons.inventory_2_outlined,
          selectedIcon: Icons.inventory_2,
          builder: (_) => const StockScreen(),
        ),
        RoleTab(
          label: 'Mon officine',
          icon: Icons.storefront_outlined,
          selectedIcon: Icons.storefront,
          builder: (_) => const PharmacyProfileScreen(),
        ),
      ],
    );
  }
}
