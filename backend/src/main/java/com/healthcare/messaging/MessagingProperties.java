package com.healthcare.messaging;

import jakarta.validation.constraints.Positive;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * @param maxVoiceSeconds    durée maximale d'un message vocal
 * @param ringTimeoutSeconds durée de sonnerie avant « appel manqué »
 * @param stunUrls           serveurs STUN (découverte de l'adresse publique, gratuits)
 * @param turnUrl            serveur TURN optionnel : relaie l'audio/vidéo quand la connexion directe
 *                           est impossible (certains réseaux mobiles ou d'entreprise)
 */
@Validated
@ConfigurationProperties(prefix = "app.messaging")
public record MessagingProperties(
        @Positive int maxVoiceSeconds,
        @Positive int ringTimeoutSeconds,
        List<String> stunUrls,
        String turnUrl,
        String turnUsername,
        String turnCredential
) {
    /** Configuration ICE envoyée aux clients WebRTC (format RTCIceServer). */
    public List<Map<String, Object>> iceServers() {
        List<Map<String, Object>> servers = new ArrayList<>();
        if (stunUrls != null && !stunUrls.isEmpty()) {
            servers.add(Map.of("urls", stunUrls));
        }
        if (turnUrl != null && !turnUrl.isBlank()) {
            Map<String, Object> turn = new LinkedHashMap<>();
            turn.put("urls", List.of(turnUrl));
            turn.put("username", turnUsername == null ? "" : turnUsername);
            turn.put("credential", turnCredential == null ? "" : turnCredential);
            servers.add(turn);
        }
        return servers;
    }
}
