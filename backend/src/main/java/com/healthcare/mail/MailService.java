package com.healthcare.mail;

import jakarta.annotation.PreDestroy;
import jakarta.mail.internet.InternetAddress;
import jakarta.mail.internet.MimeMessage;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.http.MediaType;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.util.List;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * Envoi des e-mails, hors du thread de la requête : un serveur lent ou injoignable ne bloque
 * pas l'API, et un échec est journalisé (l'utilisateur peut redemander un code).
 */
@Slf4j
@Service
public class MailService {

    private static final String BREVO_URL = "https://api.brevo.com/v3/smtp/email";

    private final MailProperties properties;
    private final ObjectProvider<JavaMailSender> smtpSender;
    private final RestClient restClient = RestClient.create();
    private final ExecutorService executor = Executors.newSingleThreadExecutor(r -> {
        Thread t = new Thread(r, "mail-sender");
        t.setDaemon(true);
        return t;
    });

    public MailService(MailProperties properties, ObjectProvider<JavaMailSender> smtpSender) {
        this.properties = properties;
        this.smtpSender = smtpSender;
    }

    /** Vrai si de vrais e-mails partent : la vérification d'e-mail est alors exigée. */
    public boolean isEnabled() {
        return properties.enabled();
    }

    public void send(String to, String subject, String text, String html) {
        if (!properties.enabled()) {
            log.warn("E-mail désactivé (MAIL_ENABLED=false), message non envoyé à {} : {} | {}", to, subject, text);
            return;
        }
        executor.execute(() -> {
            try {
                if ("brevo".equals(properties.provider())) {
                    sendWithBrevo(to, subject, text, html);
                } else {
                    sendWithSmtp(to, subject, text, html);
                }
                log.info("E-mail « {} » envoyé à {} ({})", subject, to, properties.provider());
            } catch (Exception e) {
                log.error("Échec d'envoi de l'e-mail « {} » à {} via {} : {}", subject, to, properties.provider(),
                        e.getMessage());
            }
        });
    }

    private void sendWithSmtp(String to, String subject, String text, String html) throws Exception {
        JavaMailSender sender = smtpSender.getIfAvailable();
        if (sender == null) {
            throw new IllegalStateException("SMTP non configuré (SMTP_HOST)");
        }
        MimeMessage message = sender.createMimeMessage();
        MimeMessageHelper helper = new MimeMessageHelper(message, true, "UTF-8");
        helper.setFrom(new InternetAddress(properties.from(), properties.fromName(), "UTF-8"));
        helper.setTo(to);
        helper.setSubject(subject);
        helper.setText(text, html);
        sender.send(message);
    }

    private void sendWithBrevo(String to, String subject, String text, String html) {
        if (properties.brevoApiKey() == null || properties.brevoApiKey().isBlank()) {
            throw new IllegalStateException("BREVO_API_KEY manquante");
        }
        restClient.post()
                .uri(BREVO_URL)
                .header("api-key", properties.brevoApiKey())
                .contentType(MediaType.APPLICATION_JSON)
                .accept(MediaType.APPLICATION_JSON)
                .body(Map.of(
                        "sender", Map.of("name", properties.fromName(), "email", properties.from()),
                        "to", List.of(Map.of("email", to)),
                        "subject", subject,
                        "textContent", text,
                        "htmlContent", html))
                .retrieve()
                .toBodilessEntity();
    }

    @PreDestroy
    void shutdown() {
        executor.shutdown();
    }
}
