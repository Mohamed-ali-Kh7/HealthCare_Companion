package com.healthcare.mail;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * app.mail.* : envoi des e-mails (codes de vérification, mot de passe oublié).
 *
 * @param enabled               false = rien n'est envoyé (codes écrits dans les logs) et la vérification
 *                              d'e-mail n'est pas exigée à l'inscription
 * @param provider              "smtp" (JavaMailSender, spring.mail.*) ou "brevo" (API HTTPS)
 * @param from                  adresse de l'expéditeur
 * @param fromName              nom affiché de l'expéditeur
 * @param brevoApiKey           clé API Brevo (provider = brevo)
 * @param codeTtlMinutes        durée de validité d'un code
 * @param resendCooldownSeconds délai minimal entre deux envois de code au même compte
 * @param maxAttempts           essais autorisés par code avant d'en demander un nouveau
 */
@ConfigurationProperties(prefix = "app.mail")
public record MailProperties(boolean enabled, String provider, String from, String fromName, String brevoApiKey,
                             int codeTtlMinutes, int resendCooldownSeconds, int maxAttempts) {

    public MailProperties {
        provider = (provider == null || provider.isBlank()) ? "smtp" : provider.trim().toLowerCase();
        fromName = (fromName == null || fromName.isBlank()) ? "HealthCare Companion" : fromName;
        if (codeTtlMinutes <= 0) codeTtlMinutes = 15;
        if (resendCooldownSeconds < 0) resendCooldownSeconds = 60;
        if (maxAttempts <= 0) maxAttempts = 5;
    }
}
