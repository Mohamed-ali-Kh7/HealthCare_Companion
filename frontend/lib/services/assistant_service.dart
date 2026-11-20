import '../core/network/api_client.dart';
import '../models/assistant_message.dart';

class AssistantService {
  AssistantService(this._api);

  final ApiClient _api;

  static const _base = '/api/assistant';

  /// true : réponses de l'IA ; false : mode de secours (sans IA).
  Future<bool> isAiEnabled() async =>
      ((await _api.get('$_base/status')) as Map<String, dynamic>)['aiEnabled'] as bool? ?? false;

  Future<List<AssistantMessage>> history() async => _list(await _api.get('$_base/messages'));

  /// Envoie le message du patient et renvoie la réponse de l'assistant.
  /// Délai long : l'IA peut consulter le dossier et transmettre au médecin avant de répondre.
  Future<AssistantMessage> ask(String message) async => AssistantMessage.fromJson(await _api.post('$_base/messages',
      body: {'message': message}, timeout: const Duration(seconds: 120)) as Map<String, dynamic>);

  Future<void> clear() => _api.delete('$_base/messages');

  /// « Transférer à l'assistant » : il reprend les derniers messages restés sans réponse du médecin indisponible.
  Future<AssistantMessage> handoff(int doctorId) async => AssistantMessage.fromJson(await _api.post('$_base/handoff',
      body: {'doctorId': doctorId}, timeout: const Duration(seconds: 120)) as Map<String, dynamic>);

  Future<List<AssistantDoctor>> doctors() async => ((await _api.get('$_base/doctors')) as List)
      .map((e) => AssistantDoctor.fromJson(e as Map<String, dynamic>))
      .toList();

  Future<AssistantMessage> leaveMessage(int doctorId, String message) async => AssistantMessage.fromJson(await _api
      .post('$_base/doctor-message', body: {'doctorId': doctorId, 'message': message}) as Map<String, dynamic>);

  List<AssistantMessage> _list(dynamic json) =>
      (json as List).map((e) => AssistantMessage.fromJson(e as Map<String, dynamic>)).toList();
}
