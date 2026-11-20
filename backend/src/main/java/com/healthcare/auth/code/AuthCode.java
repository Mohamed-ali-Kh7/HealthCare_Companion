package com.healthcare.auth.code;

import com.healthcare.common.BaseEntity;
import com.healthcare.user.User;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.Instant;

/**
 * Code à 6 chiffres envoyé par e-mail. Seule son empreinte est stockée (jamais le code en clair).
 * Un code est à usage unique, expire, et ne supporte qu'un nombre limité d'essais.
 */
@Entity
@Table(name = "auth_codes", indexes = @Index(name = "idx_auth_codes_user_purpose", columnList = "user_id, purpose"))
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class AuthCode extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    private CodePurpose purpose;

    /** SHA-256 hexadécimal. */
    @Column(name = "code_hash", nullable = false, length = 64)
    private String codeHash;

    @Column(name = "expires_at", nullable = false)
    private Instant expiresAt;

    @Column(nullable = false)
    private int attempts;

    /** Utilisé, remplacé par un nouveau code ou bloqué après trop d'essais. */
    @Column(nullable = false)
    private boolean consumed;

    public AuthCode(User user, CodePurpose purpose, String codeHash, Instant expiresAt) {
        this.user = user;
        this.purpose = purpose;
        this.codeHash = codeHash;
        this.expiresAt = expiresAt;
    }

    public void registerFailedAttempt() {
        attempts++;
    }

    public void consume() {
        consumed = true;
    }
}
