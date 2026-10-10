/// Statistiques de supervision (/api/admin/dashboard).
class Dashboard {
  const Dashboard({
    required this.usersByRole,
    required this.pendingOrDisabledAccounts,
    required this.appointmentsByStatus,
    required this.pharmacies,
    required this.medicines,
    required this.specialities,
    required this.sensorReadingsLast24h,
  });

  final Map<String, int> usersByRole;
  final int pendingOrDisabledAccounts;
  final Map<String, int> appointmentsByStatus;
  final int pharmacies;
  final int medicines;
  final int specialities;
  final int sensorReadingsLast24h;

  factory Dashboard.fromJson(Map<String, dynamic> json) => Dashboard(
        usersByRole: _intMap(json['usersByRole']),
        pendingOrDisabledAccounts: json['pendingOrDisabledAccounts'] as int,
        appointmentsByStatus: _intMap(json['appointmentsByStatus']),
        pharmacies: json['pharmacies'] as int,
        medicines: json['medicines'] as int,
        specialities: json['specialities'] as int,
        sensorReadingsLast24h: json['sensorReadingsLast24h'] as int,
      );

  static Map<String, int> _intMap(dynamic raw) =>
      (raw as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as num).toInt()));
}
