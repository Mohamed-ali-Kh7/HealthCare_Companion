import 'package:intl/intl.dart';

/// Formats d'affichage (français) et conversions vers les formats attendus par l'API.
class Fmt {
  Fmt._();

  static final _date = DateFormat('dd/MM/yyyy', 'fr_FR');
  static final _dateLong = DateFormat('EEEE d MMMM yyyy', 'fr_FR');
  static final _time = DateFormat('HH:mm', 'fr_FR');
  static final _dateTime = DateFormat('dd/MM/yyyy HH:mm', 'fr_FR');
  static final _dayShort = DateFormat('E d', 'fr_FR');

  static String date(DateTime? d) => d == null ? '—' : _date.format(d);
  static String dateLong(DateTime d) => _dateLong.format(d);
  static String time(DateTime d) => _time.format(d);
  static String dateTime(DateTime d) => _dateTime.format(d);
  static String dayShort(DateTime d) => _dayShort.format(d);

  /// LocalDate côté API : "2026-10-12"
  static String apiDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

  /// LocalDateTime côté API (heure locale, sans fuseau) : "2026-10-12T09:30:00"
  static String apiLocalDateTime(DateTime d) =>
      '${apiDate(d)}T${_two(d.hour)}:${_two(d.minute)}:00';

  /// LocalTime côté API : "08:00"
  static String apiTime(int hour, int minute) => '${_two(hour)}:${_two(minute)}';

  /// Montant en dinars (3 décimales).
  static String price(num? value) => value == null ? '—' : '${value.toStringAsFixed(3)} TND';

  static String _two(int v) => v.toString().padLeft(2, '0');
}

/// Lecture des dates renvoyées par l'API.
class ApiDates {
  ApiDates._();

  /// LocalDate / LocalDateTime (sans fuseau) → DateTime locale.
  static DateTime? parseLocal(dynamic value) =>
      value == null ? null : DateTime.parse(value as String);

  /// Instant UTC ("...Z") → DateTime dans le fuseau du téléphone.
  static DateTime? parseInstant(dynamic value) =>
      value == null ? null : DateTime.parse(value as String).toLocal();

  /// LocalTime "08:00:00" → (heure, minute)
  static ({int hour, int minute}) parseTime(String value) {
    final parts = value.split(':');
    return (hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }
}
