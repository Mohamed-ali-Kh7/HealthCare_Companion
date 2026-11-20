import 'dart:typed_data';

import '../core/network/api_client.dart';
import '../models/message.dart';

/// Messagerie patient - médecin. [contactId] : id du médecin (patient) ou du patient (médecin).
class MessagingService {
  MessagingService(this._api);

  final ApiClient _api;

  static const _base = '/api/messages';

  Future<List<Conversation>> getConversations() async => (await _api.get('$_base/conversations') as List)
      .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
      .toList();

  Future<int> getUnreadCount() async =>
      ((await _api.get('$_base/unread-count') as Map<String, dynamic>)['unreadCount'] as num).toInt();

  /// Sans curseur : les derniers messages. [afterId] : nouveaux messages. [beforeId] : historique plus ancien.
  /// Toujours dans l'ordre chronologique.
  Future<List<ChatMessage>> getMessages(int contactId, {int? beforeId, int? afterId}) async =>
      _list(await _api.get('$_base/conversations/$contactId', query: {'beforeId': beforeId, 'afterId': afterId}));

  Future<ChatMessage> sendText(int contactId, String content) async =>
      _one(await _api.post('$_base/conversations/$contactId', body: {'content': content}));

  Future<ChatMessage> sendVoice(int contactId,
          {required Uint8List bytes, required String contentType, required int durationMs}) async =>
      _one(await _api.postFile(
        '$_base/conversations/$contactId/voice',
        field: 'file',
        bytes: bytes,
        filename: 'vocal.${contentType.split('/').last}',
        contentType: contentType,
        fields: {'durationMs': '$durationMs'},
      ));

  Future<({Uint8List bytes, String? contentType})> getAudio(int messageId) =>
      _api.download('$_base/$messageId/audio');

  Future<void> markAsRead(int contactId) async => _api.put('$_base/conversations/$contactId/read');

  List<ChatMessage> _list(dynamic json) =>
      (json as List).map((e) => ChatMessage.fromJson(e as Map<String, dynamic>)).toList();

  ChatMessage _one(dynamic json) => ChatMessage.fromJson(json as Map<String, dynamic>);
}
