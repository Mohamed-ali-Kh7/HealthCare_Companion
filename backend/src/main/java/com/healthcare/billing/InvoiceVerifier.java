package com.healthcare.billing;

import com.healthcare.security.JwtProperties;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.security.MessageDigest;
import java.util.Base64;
import java.util.Optional;

/**
 * Lien signé (HMAC-SHA256) imprimé en QR code sur la facture PDF : « id-signature ».
 * Même principe que pour les ordonnances, avec une clé d'usage distinct.
 */
@Component
public class InvoiceVerifier {

    private static final String PATH = "/verify/invoice/";
    private static final int SIGNATURE_BYTES = 16;

    private final byte[] key;
    private final String publicBaseUrl;

    public InvoiceVerifier(JwtProperties jwt, @Value("${app.public-base-url}") String publicBaseUrl) {
        this.key = ("invoice-verification:" + jwt.secret()).getBytes(StandardCharsets.UTF_8);
        this.publicBaseUrl = publicBaseUrl.replaceAll("/+$", "");
    }

    public String url(Long invoiceId) {
        return publicBaseUrl + PATH + invoiceId + "-" + sign(invoiceId);
    }

    public Optional<Long> verify(String token) {
        if (token == null) {
            return Optional.empty();
        }
        int dash = token.indexOf('-');
        if (dash <= 0) {
            return Optional.empty();
        }
        long id;
        try {
            id = Long.parseLong(token.substring(0, dash));
        } catch (NumberFormatException e) {
            return Optional.empty();
        }
        byte[] expected = sign(id).getBytes(StandardCharsets.US_ASCII);
        byte[] given = token.substring(dash + 1).getBytes(StandardCharsets.US_ASCII);
        return MessageDigest.isEqual(expected, given) ? Optional.of(id) : Optional.empty();
    }

    private String sign(long id) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(key, "HmacSHA256"));
            byte[] full = mac.doFinal(Long.toString(id).getBytes(StandardCharsets.US_ASCII));
            byte[] truncated = new byte[SIGNATURE_BYTES];
            System.arraycopy(full, 0, truncated, 0, SIGNATURE_BYTES);
            return Base64.getUrlEncoder().withoutPadding().encodeToString(truncated);
        } catch (GeneralSecurityException e) {
            throw new IllegalStateException("HMAC-SHA256 indisponible", e);
        }
    }
}
