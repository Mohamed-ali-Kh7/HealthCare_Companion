package com.healthcare.security;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.io.Decoders;
import io.jsonwebtoken.security.Keys;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.time.Instant;
import java.util.Date;

@Service
public class JwtService {

    private final JwtProperties props;
    private final SecretKey key;

    public JwtService(JwtProperties props) {
        this.props = props;
        // Lève WeakKeyException au démarrage si la clé fait moins de 256 bits
        this.key = Keys.hmacShaKeyFor(decodeSecret(props.secret()));
    }

        /** Accepte Base64 standard ou Base64URL ; sinon message explicite au démarrage. */
    private static byte[] decodeSecret(String secret) {
        String value = secret.trim();
        try {
            return Decoders.BASE64.decode(value);
        } catch (RuntimeException standard) {
            try {
                return Decoders.BASE64URL.decode(value);
            } catch (RuntimeException url) {
                throw new IllegalStateException(
                        "JWT_SECRET doit être une clé encodée en Base64 (32 octets minimum). "
                                + "Générez-en une avec : openssl rand -base64 32", url);
            }
        }
    }

    public String generateToken(SecurityUser user) {
        Instant now = Instant.now();
        return Jwts.builder()
                .issuer(props.issuer())
                .subject(user.id().toString())
                .claim("role", user.role().name()) // informatif : les droits viennent de la base
                .issuedAt(Date.from(now))
                .expiration(Date.from(now.plusMillis(props.expirationMs())))
                .signWith(key) // HS256
                .compact();
    }

    /**
     * Vérifie signature, émetteur et expiration, puis renvoie l'id utilisateur.
     *
     * @throws JwtException si le token est invalide ou expiré
     */
    public Long extractUserId(String token) {
        Claims claims = Jwts.parser()
                .verifyWith(key)
                .requireIssuer(props.issuer())
                .build()
                .parseSignedClaims(token)
                .getPayload();
        return Long.valueOf(claims.getSubject());
    }

    public long getExpirationSeconds() {
        return props.expirationMs() / 1000;
    }
}
