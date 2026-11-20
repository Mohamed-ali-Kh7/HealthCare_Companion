import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/calls/call_service.dart';
import 'core/network/api_client.dart';
import 'core/notifications/appointment_reminder_service.dart';
import 'core/notifications/reminder_service.dart';
import 'core/sensors/sensor_collector.dart';
import 'core/storage/token_storage.dart';
import 'providers/auth_provider.dart';
import 'services/admin_service.dart';
import 'services/ambulance_service.dart';
import 'services/appointment_service.dart';
import 'services/auth_service.dart';
import 'services/doctor_service.dart';
import 'services/medication_service.dart';
import 'services/medicine_service.dart';
import 'services/messaging_service.dart';
import 'services/assistant_service.dart';
import 'services/journal_service.dart';
import 'services/billing_service.dart';
import 'services/transport_service.dart';
import 'services/order_service.dart';
import 'services/patient_service.dart';
import 'services/pharmacy_service.dart';
import 'services/prescription_service.dart';
import 'services/stats_service.dart';
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
        Provider<AmbulanceService>(create: (_) => AmbulanceService(apiClient)),
        Provider<OrderService>(create: (_) => OrderService(apiClient)),
        Provider<BillingService>(create: (_) => BillingService(apiClient)),
        Provider<TransportService>(create: (_) => TransportService(apiClient)),
        Provider<JournalService>(create: (_) => JournalService(apiClient)),
        Provider<AssistantService>(create: (_) => AssistantService(apiClient)),
        Provider<StatsService>(create: (_) => StatsService(apiClient)),
        Provider<ReminderService>(create: (_) => ReminderService()),
        Provider<AppointmentReminderService>(
          create: (ctx) => AppointmentReminderService(ctx.read<AppointmentService>(), ctx.read<ReminderService>()),
          dispose: (_, s) => s.dispose(),
        ),
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
        Provider<MessagingService>(create: (_) => MessagingService(apiClient)),
        // Appels : connecté au serveur tant qu'un patient ou un médecin est connecté
        ChangeNotifierProxyProvider<AuthProvider, CallService>(
          create: (_) => CallService(tokenStorage),
          update: (_, auth, calls) => calls!..onAuthChanged(auth.status, auth.user?.role),
        ),
      ],
      child: const HealthcareApp(),
    ),
  );
}
