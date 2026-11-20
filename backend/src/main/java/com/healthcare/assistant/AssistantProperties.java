package com.healthcare.assistant;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * app.assistant.* : sans clé API, l'assistant fonctionne en mode de secours (règles, sans IA).
 *
 * @param apiKey          clé Anthropic (variable ANTHROPIC_API_KEY) ; vide = mode de secours
 * @param model           modèle Claude
 * @param historySize     messages précédents renvoyés au modèle (contexte de la conversation)
 * @param serverFallbacks repli automatique côté serveur si le modèle refuse une demande
 * @param baseUrl         adresse de l'API (vide = API Anthropic ; utile pour un proxy ou les tests)
 */
@ConfigurationProperties(prefix = "app.assistant")
public record AssistantProperties(String apiKey, String model, int historySize, boolean serverFallbacks,
                                  String baseUrl) {

    public AssistantProperties {
        if (model == null || model.isBlank()) {
            model = "claude-opus-5-5";
        }
        if (historySize <= 0) {
            historySize = 20;
        }
    }

    public boolean aiEnabled() {
        return apiKey != null && !apiKey.isBlank();
    }
}
