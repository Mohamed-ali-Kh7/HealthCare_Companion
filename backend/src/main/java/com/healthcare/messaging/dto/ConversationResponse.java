package com.healthcare.messaging.dto;

import com.healthcare.messaging.MessageType;

import java.time.Instant;

/**
 * Une conversation vue par l'utilisateur connecté.
 * {@code contactId} : id du médecin (côté patient) ou du patient (côté médecin).
 * {@code contactSubtitle} : spécialité du médecin, vide côté médecin.
 * {@code lastMessage} : texte du dernier message (null pour un vocal ou un appel : voir {@code lastMessageType}).
 */
public record ConversationResponse(
        Long contactId,
        String contactFirstName,
        String contactLastName,
        String contactSubtitle,
        MessageType lastMessageType,
        String lastMessage,
        Instant lastMessageAt,
        boolean lastMessageMine,
        long unreadCount,
        /** Côté patient : le médecin est absent (message et date de retour facultatifs). Toujours false côté médecin. */
        boolean contactAway,
        String contactAwayMessage,
        java.time.LocalDate contactAwayUntil
) {
}
