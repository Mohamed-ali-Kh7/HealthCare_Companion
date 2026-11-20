package com.healthcare.prescription;

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
 * Lien de vérification imprimé en QR code sur l'ordonnance PDF.
 * Jeton = « id-signature » : la signature HMAC-SHA256 empêche de fabriquer un lien valide
 * ou de parcourir les ordonnances des autres en changeant le numéro.
 * Clé dérivée du secret JWT (aucun nouveau secret à gérer), avec un usage distinct.
 */
@Component
public class PrescriptionVerifier {

    private static final String PATH = "/verify/prescription/";
    /** 128 bits de signature : largement suffisant contre la devinette, QR code compact. */
    private static final int SIGNATURE_BYTES = 16;

    private final byte[] key;
    private final String publicBaseUrl;

    public PrescriptionVerifier(JwtProperties jwt, @Value("${app.public-base-url}") String publicBaseUrl) {
        this.key = ("prescription-verification:" + jwt.secret()).getBytes(StandardCharsets.UTF_8);
        this.publicBaseUrl = publicBaseUrl.replaceAll("/+$", "");
    }

    /** URL complète encodée dans le QR code. */
    public String url(Long prescriptionId) {
        return publicBaseUrl + PATH + token(prescriptionId);
    }

    String token(Long prescriptionId) {
        return prescriptionId + "-" + sign(prescriptionId);
    }

    /** Id de l'ordonnance si le jeton est authentique ; vide sinon (falsifié, mal formé). */
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
        // Comparaison à temps constant : ne révèle pas la signature attendue
        return MessageDigest.isEqual(expected, given) ? Optional.of(id) : Optional.empty();
    }

    private String sign(long prescriptionId) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(key, "HmacSHA256"));
            byte[] full = mac.doFinal(Long.toString(prescriptionId).getBytes(StandardCharsets.US_ASCII));
            byte[] truncated = new byte[SIGNATURE_BYTES];
            System.arraycopy(full, 0, truncated, 0, SIGNATURE_BYTES);
            return Base64.getUrlEncoder().withoutPadding().encodeToString(truncated);
        } catch (GeneralSecurityException e) {
            throw new IllegalStateException("HMAC-SHA256 indisponible", e);
        }
    }
}
