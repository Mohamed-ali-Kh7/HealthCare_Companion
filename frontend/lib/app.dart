import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'models/user.dart';
import 'providers/auth_provider.dart';
import 'screens/admin/admin_home_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/doctor/doctor_home_screen.dart';
import 'screens/patient/patient_home_screen.dart';
import 'screens/pharmacist/pharmacist_home_screen.dart';

class HealthcareApp extends StatelessWidget {
  const HealthcareApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return MaterialApp(
      // Nouvelle clé à chaque changement de session : la pile de navigation est réinitialisée
      // (aucun écran de l'utilisateur précédent ne reste ouvert après une déconnexion).
      key: ValueKey('${auth.status}-${auth.user?.id}'),
      title: 'HealthCare Companion',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: switch (auth.status) {
        AuthStatus.unknown => const SplashScreen(),
        AuthStatus.unauthenticated => const LoginScreen(),
        AuthStatus.authenticated => _homeFor(auth.user!.role),
      },
    );
  }

  /// RBAC côté interface : chaque rôle a son propre espace.
  /// (La vraie sécurité reste côté API : ces écrans ne font qu'appeler des endpoints autorisés.)
  Widget _homeFor(UserRole role) => switch (role) {
        UserRole.patient => const PatientHomeScreen(),
        UserRole.doctor => const DoctorHomeScreen(),
        UserRole.pharmacist => const PharmacistHomeScreen(),
        UserRole.admin => const AdminHomeScreen(),
      };
}
