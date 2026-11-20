import 'package:url_launcher/url_launcher.dart';

/// Numéros d'urgence en Tunisie.
class EmergencyNumbers {
  EmergencyNumbers._();

  static const samu = '190';
  static const civilProtection = '198';
}

/// Ouverture d'applications externes (téléphone, carte).
class Launcher {
  Launcher._();

  /// Ouvre le composeur téléphonique. Renvoie false si l'appareil ne sait pas appeler (ex : navigateur).
  static Future<bool> call(String number) async {
    try {
      return await launchUrl(Uri(scheme: 'tel', path: number));
    } catch (_) {
      return false;
    }
  }

  /// Position du patient sur OpenStreetMap (sans clé API, comme la carte des pharmacies).
  static Future<bool> openMap(double lat, double lng) async {
    try {
      return await launchUrl(
        Uri.https('www.openstreetmap.org', '/',
            {'mlat': '$lat', 'mlon': '$lng', 'zoom': '17'}),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }
}
