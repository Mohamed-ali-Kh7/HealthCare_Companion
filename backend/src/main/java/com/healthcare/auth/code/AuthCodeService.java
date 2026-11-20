package com.healthcare.auth.code;

import com.healthcare.common.exception.BusinessRuleException;
import com.healthcare.mail.MailProperties;
import com.healthcare.user.User;
import lombok.RequiredArgsConstructor;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.HexFormat;

/** Création et vérification des codes envoyés par e-mail (inscription, mot de passe oublié). */
@Service
@RequiredArgsConstructor
public class AuthCodeService {

    private static final SecureRandom RANDOM = new SecureRandom();

    private final AuthCodeRepository repository;
    private final MailProperties properties;
    private final ApplicationEventPublisher events;
    private final Clock clock;

    /**
     * Crée un nouveau code (les précédents du même usage deviennent invalides) et déclenche l'e-mail.
     * Ignoré si un code a été envoyé il y a moins de resendCooldownSeconds (anti-spam).
     *
     * @return true si un code a été envoyé
     */
    @Transactional
    public boolean issue(User user, CodePurpose purpose) {
        Instant now = clock.instant();
        boolean tooSoon = repository.findFirstByUserAndPurposeOrderByIdDesc(user, purpose)
                .map(last -> last.getCreatedAt() != null
                        && last.getCreatedAt().plusSeconds(properties.resendCooldownSeconds()).isAfter(now))
                .orElse(false);
        if (tooSoon) {
            return false;
        }
        repository.findByUserAndPurposeAndConsumedFalse(user, purpose).forEach(AuthCode::consume);

        String code = "%06d".formatted(RANDOM.nextInt(1_000_000));
        Instant expiresAt = now.plus(Duration.ofMinutes(properties.codeTtlMinutes()));
        repository.save(new AuthCode(user, purpose, hash(user, purpose, code), expiresAt));
        events.publishEvent(new AuthCodeIssuedEvent(user.getEmail(), purpose, code, properties.codeTtlMinutes()));
        return true;
    }

    /**
     * Vérifie le code et le consomme s'il est bon. Un essai raté est enregistré même si la
     * transaction de l'appelant est annulée (REQUIRES_NEW), sinon la limite d'essais serait contournable.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW, noRollbackFor = BusinessRuleException.class)
    public void verify(User user, CodePurpose purpose, String code) {
        AuthCode current = repository.findFirstByUserAndPurposeAndConsumedFalseOrderByIdDesc(user, purpose)
                .orElseThrow(AuthCodeService::invalidCode);
        if (current.getExpiresAt().isBefore(clock.instant())) {
            current.consume();
            throw new BusinessRuleException("CODE_EXPIRED", "Ce code a expiré. Demandez-en un nouveau.");
        }
        byte[] expected = current.getCodeHash().getBytes(StandardCharsets.US_ASCII);
        byte[] actual = hash(user, purpose, code == null ? "" : code.trim()).getBytes(StandardCharsets.US_ASCII);
        if (!MessageDigest.isEqual(expected, actual)) {
            current.registerFailedAttempt();
            if (current.getAttempts() >= properties.maxAttempts()) {
                current.consume();
                throw new BusinessRuleException("TOO_MANY_ATTEMPTS",
                        "Trop d'essais incorrects. Demandez un nouveau code.");
            }
            throw invalidCode();
        }
        current.consume();
    }

    /** Même erreur que pour un mauvais code : ne révèle pas si l'e-mail est inscrit. */
    public static BusinessRuleException invalidCode() {
        return new BusinessRuleException("INVALID_CODE", "Code incorrect ou expiré");
    }

    private static String hash(User user, CodePurpose purpose, String code) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            String input = user.getId() + ":" + purpose + ":" + code;
            return HexFormat.of().formatHex(digest.digest(input.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }
}
