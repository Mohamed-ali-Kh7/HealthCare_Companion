/// Configuration de l'application.
///
/// L'URL de l'API se change sans modifier le code :
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8080
///
/// Valeur par défaut : 10.0.2.2 = la machine hôte vue depuis l'émulateur Android.
class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8081',
  );

  /// Même fuseau que le backend (app.timezone) : rendez-vous et rappels.
  static const String timezone = 'Africa/Tunis';

  static const Duration requestTimeout = Duration(seconds: 20);

  /// Position par défaut si la géolocalisation est refusée (centre de Tunis).
  static const double defaultLatitude = 36.8065;
  static const double defaultLongitude = 10.1815;

  /// Intervalle d'envoi automatique des mesures capteurs pendant que l'app est ouverte.
  static const Duration sensorSyncInterval = Duration(minutes: 15);
}
