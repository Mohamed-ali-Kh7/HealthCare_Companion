import 'package:geolocator/geolocator.dart';

import '../config/app_config.dart';

typedef GeoPoint = ({double lat, double lng, bool isFallback});

/// Position actuelle du téléphone, avec repli sur le centre de Tunis
/// si la localisation est désactivée ou refusée (l'app reste utilisable).
class LocationHelper {
  LocationHelper._();

  static const GeoPoint fallback =
      (lat: AppConfig.defaultLatitude, lng: AppConfig.defaultLongitude, isFallback: true);

  static Future<GeoPoint> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return fallback;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return fallback;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return (lat: position.latitude, lng: position.longitude, isFallback: false);
    } catch (_) {
      return fallback;
    }
  }
}
