package com.healthcare.messaging.dto;

import com.healthcare.messaging.Message;
import com.healthcare.messaging.MessageType;
import com.healthcare.user.Role;

import java.time.Instant;

/**
 * {@code mine} : vrai si le message a été écrit (ou l'appel passé) par l'utilisateur connecté.
 * VOICE : l'audio se télécharge sur {@code GET /api/messages/{id}/audio}.
 * CALL : {@code callDurationSeconds} null = appel non abouti (manqué, refusé ou annulé).
 */
public record MessageResponse(
        Long id,
        MessageType type,
        Role senderRole,
        boolean mine,
        String content,
        Integer audioDurationMs,
        Boolean callVideo,
        Integer callDurationSeconds,
        Instant sentAt,
        Instant readAt
) {
    public static MessageResponse from(Message m, Role viewerRole) {
        return new MessageResponse(m.getId(), m.getType(), m.getSenderRole(), m.getType() != MessageType.ASSISTANT && m.getSenderRole() == viewerRole,
                m.getContent(), m.getAudioDurationMs(), m.getCallVideo(), m.getCallDurationSeconds(),
                m.getCreatedAt(), m.getReadAt());
    }
}
