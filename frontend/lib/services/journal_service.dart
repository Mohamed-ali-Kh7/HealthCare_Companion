import '../core/network/api_client.dart';
import '../core/utils/formatters.dart';
import '../models/symptom_entry.dart';

class JournalService {
  JournalService(this._api);

  final ApiClient _api;

  /// Crée ou remplace l'entrée du jour.
  Future<SymptomEntry> save(SymptomEntry entry) async =>
      SymptomEntry.fromJson(await _api.put('/api/journal/me', body: entry.toJson()) as Map<String, dynamic>);

  Future<List<SymptomEntry>> getMine({int days = 30}) async =>
      _list(await _api.get('/api/journal/me', query: {'days': days}));

  Future<void> delete(DateTime date) => _api.delete('/api/journal/me/${Fmt.apiDate(date)}');

  /// Médecin : journal d'un patient suivi.
  Future<List<SymptomEntry>> getForPatient(int patientId, {int days = 30}) async =>
      _list(await _api.get('/api/journal/patients/$patientId', query: {'days': days}));

  List<SymptomEntry> _list(dynamic json) =>
      (json as List).map((e) => SymptomEntry.fromJson(e as Map<String, dynamic>)).toList();
}
