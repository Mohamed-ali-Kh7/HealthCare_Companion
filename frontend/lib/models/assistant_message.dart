import '../core/utils/formatters.dart';

class AssistantMessage {
  const AssistantMessage({
    required this.id,
    required this.fromPatient,
    required this.content,
    required this.createdAt,
    this.urgent = false,
    this.urgencyReason,
    this.forwardedTo = const [],
    this.aiGenerated = false,
  });

  final int id;
  final bool fromPatient;
  final String content;
  final DateTime createdAt;
  final bool urgent;
  final String? urgencyReason;

  /// Médecins à qui la demande a été transmise.
  final List<String> forwardedTo;

  /// Réponse de l'IA (true) ou du mode de secours (false).
  final bool aiGenerated;

  factory AssistantMessage.fromJson(Map<String, dynamic> json) => AssistantMessage(
        id: json['id'] as int,
        fromPatient: json['role'] == 'USER',
        content: json['content'] as String,
        createdAt: ApiDates.parseInstant(json['createdAt']) ?? DateTime.now(),
        urgent: json['urgent'] as bool? ?? false,
        urgencyReason: json['urgencyReason'] as String?,
        forwardedTo: (json['forwardedTo'] as List? ?? const []).cast<String>(),
        aiGenerated: json['aiGenerated'] as bool? ?? false,
      );
}

class AssistantDoctor {
  const AssistantDoctor({required this.id, required this.name, required this.speciality});

  final int id;
  final String name;
  final String speciality;

  factory AssistantDoctor.fromJson(Map<String, dynamic> json) => AssistantDoctor(
        id: json['id'] as int,
        name: json['name'] as String,
        speciality: json['speciality'] as String,
      );
}
