import '../core/utils/formatters.dart';

enum MessageType {
  text('TEXT'),
  voice('VOICE'),
  call('CALL'),
  assistant('ASSISTANT');

  const MessageType(this.apiValue);

  final String apiValue;

  static MessageType fromApi(String value) => MessageType.values.firstWhere((t) => t.apiValue == value);
}

/// Une conversation vue par l'utilisateur connecté.
/// [contactId] : id du médecin (côté patient) ou du patient (côté médecin).
class Conversation {
  const Conversation({
    required this.contactId,
    required this.contactFirstName,
    required this.contactLastName,
    required this.lastMessageMine,
    required this.unreadCount,
    this.contactSubtitle,
    this.lastMessageType,
    this.lastMessage,
    this.lastMessageAt,
    this.contactAway = false,
    this.contactAwayMessage,
    this.contactAwayUntil,
  });

  /// Côté patient : le médecin est absent (toujours false côté médecin).
  final bool contactAway;
  final String? contactAwayMessage;
  final DateTime? contactAwayUntil;

  final int contactId;
  final String contactFirstName;
  final String contactLastName;

  /// Spécialité du médecin (côté patient), null côté médecin.
  final String? contactSubtitle;
  final MessageType? lastMessageType;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final bool lastMessageMine;
  final int unreadCount;

  /// Côté patient, le contact est un médecin.
  String displayName({required bool isDoctor}) =>
      isDoctor ? 'Dr $contactFirstName $contactLastName' : '$contactFirstName $contactLastName';

  String get initials =>
      '${contactFirstName.isEmpty ? '' : contactFirstName[0]}${contactLastName.isEmpty ? '' : contactLastName[0]}'
          .toUpperCase();

  /// Aperçu du dernier message dans la liste.
  String get preview {
    final prefix = lastMessageMine ? 'Vous : ' : '';
    return switch (lastMessageType) {
      null => 'Aucun message',
      MessageType.text => '$prefix${lastMessage ?? ''}',
      MessageType.voice => '${prefix}Message vocal',
      MessageType.call => lastMessageMine ? 'Appel émis' : 'Appel reçu',
      MessageType.assistant => '🤖 Assistant : ${lastMessage ?? ''}',
    };
  }

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        contactId: json['contactId'] as int,
        contactFirstName: json['contactFirstName'] as String,
        contactLastName: json['contactLastName'] as String,
        contactSubtitle: json['contactSubtitle'] as String?,
        lastMessageType:
            json['lastMessageType'] == null ? null : MessageType.fromApi(json['lastMessageType'] as String),
        lastMessage: json['lastMessage'] as String?,
        lastMessageAt: ApiDates.parseInstant(json['lastMessageAt']),
        lastMessageMine: json['lastMessageMine'] as bool,
        unreadCount: (json['unreadCount'] as num).toInt(),
        contactAway: json['contactAway'] as bool? ?? false,
        contactAwayMessage: json['contactAwayMessage'] as String?,
        contactAwayUntil: json['contactAwayUntil'] == null ? null : DateTime.parse(json['contactAwayUntil'] as String),
      );
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.type,
    required this.mine,
    required this.sentAt,
    this.content,
    this.audioDurationMs,
    this.callVideo,
    this.callDurationSeconds,
    this.readAt,
  });

  final int id;
  final MessageType type;
  final bool mine;
  final String? content;
  final int? audioDurationMs;
  final bool? callVideo;

  /// null = appel non abouti (manqué, refusé ou annulé).
  final int? callDurationSeconds;
  final DateTime sentAt;
  final DateTime? readAt;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as int,
        type: MessageType.fromApi(json['type'] as String),
        mine: json['mine'] as bool,
        content: json['content'] as String?,
        audioDurationMs: json['audioDurationMs'] as int?,
        callVideo: json['callVideo'] as bool?,
        callDurationSeconds: json['callDurationSeconds'] as int?,
        sentAt: ApiDates.parseInstant(json['sentAt'])!,
        readAt: ApiDates.parseInstant(json['readAt']),
      );
}
