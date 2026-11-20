package com.healthcare.messaging;

public enum MessageType {
    /** Message écrit. */
    TEXT,
    /** Message vocal : l'audio est stocké à part (MessageAudio). */
    VOICE,
    /** Invitation à un appel audio ou vidéo (salle de visioconférence). */
    CALL,
    /** Réponse automatique de l'assistant santé quand le médecin est absent (jamais « mien »). */
    ASSISTANT
}
