import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/network/api_client.dart';
import 'core/notifications/reminder_service.dart';
import 'core/sensors/sensor_collector.dart';
import 'core/storage/token_storage.dart';
import 'providers/auth_provider.dart';
import 'services/admin_service.dart';
import 'services/appointment_service.dart';
import 'services/auth_service.dart';
import 'services/doctor_service.dart';
import 'services/medication_service.dart';
import 'services/medicine_service.dart';
import 'services/patient_service.dart';
import 'services/pharmacy_service.dart';
import 'services/prescription_service.dart';
import 'services/telemonitoring_service.dart';

/// Point d'entrée : assemble les dépendances (injection via Provider).
/// UI (screens/widgets) → services (appels REST) → ApiClient (HTTP + JWT).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR');

  final tokenStorage = TokenStorage();
  final apiClient = ApiClient(tokenStorage: tokenStorage);

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: apiClient),
        Provider<AuthService>(create: (_) => AuthService(apiClient)),
        Provider<PatientService>(create: (_) => PatientService(apiClient)),
        Provider<DoctorService>(create: (_) => DoctorService(apiClient)),
        Provider<AppointmentService>(create: (_) => AppointmentService(apiClient)),
        Provider<MedicineService>(create: (_) => MedicineService(apiClient)),
        Provider<PrescriptionService>(create: (_) => PrescriptionService(apiClient)),
        Provider<MedicationService>(create: (_) => MedicationService(apiClient)),
        Provider<PharmacyService>(create: (_) => PharmacyService(apiClient)),
        Provider<TelemonitoringService>(create: (_) => TelemonitoringService(apiClient)),
        Provider<AdminService>(create: (_) => AdminService(apiClient)),
        Provider<ReminderService>(create: (_) => ReminderService()),
        ChangeNotifierProvider<AuthProvider>(
          create: (context) => AuthProvider(
            authService: context.read<AuthService>(),
            tokenStorage: tokenStorage,
            apiClient: apiClient,
          )..restoreSession(),
        ),
        ChangeNotifierProvider<SensorCollector>(
          create: (context) => SensorCollector(context.read<TelemonitoringService>()),
        ),
      ],
      child: const HealthcareApp(),
    ),
  );
}
