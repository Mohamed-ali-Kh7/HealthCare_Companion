package com.healthcare.auth.code;

import com.healthcare.mail.MailService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;
import org.springframework.web.util.HtmlUtils;

/**
 * Rédige et envoie l'e-mail contenant le code, une fois la transaction validée :
 * aucun e-mail n'est envoyé pour une inscription finalement annulée.
 */
@Component
@RequiredArgsConstructor
public class AuthCodeMailer {

    private final MailService mailService;

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
    public void onCodeIssued(AuthCodeIssuedEvent event) {
        boolean verification = event.purpose() == CodePurpose.EMAIL_VERIFICATION;
        String subject = verification
                ? "Votre code de vérification HealthCare Companion"
                : "Réinitialisation de votre mot de passe HealthCare Companion";
        String intro = verification
                ? "Bienvenue sur HealthCare Companion ! Pour activer votre compte, saisissez ce code dans l'application :"
                : "Vous avez demandé à réinitialiser votre mot de passe. Saisissez ce code dans l'application :";
        String outro = verification
                ? "Si vous n'êtes pas à l'origine de cette inscription, ignorez cet e-mail."
                : "Si vous n'avez pas fait cette demande, ignorez cet e-mail : votre mot de passe reste inchangé.";
        String validity = "Ce code est valable " + event.ttlMinutes() + " minutes.";

        String text = intro + "\n\n    " + event.code() + "\n\n" + validity + "\n\n" + outro
                + "\n\n— L'équipe HealthCare Companion";

        String html = """
                <div style="font-family:Arial,Helvetica,sans-serif;max-width:480px;margin:auto;color:#1f2933">
                  <h2 style="color:#00695c;margin-bottom:4px">HealthCare Companion</h2>
                  <p>%s</p>
                  <p style="font-size:32px;font-weight:bold;letter-spacing:8px;text-align:center;
                            background:#e0f2f1;color:#004d40;padding:16px;border-radius:8px">%s</p>
                  <p>%s</p>
                  <p style="color:#616e7c;font-size:13px">%s</p>
                  <p style="color:#616e7c;font-size:13px">— L'équipe HealthCare Companion</p>
                </div>
                """.formatted(HtmlUtils.htmlEscape(intro), event.code(), HtmlUtils.htmlEscape(validity),
                HtmlUtils.htmlEscape(outro));

        mailService.send(event.email(), subject, text, html);
    }
}
