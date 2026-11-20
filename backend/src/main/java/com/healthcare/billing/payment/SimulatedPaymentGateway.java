package com.healthcare.billing.payment;

import org.springframework.stereotype.Component;

import java.security.SecureRandom;
import java.time.Clock;
import java.time.YearMonth;
import java.util.HexFormat;

/**
 * Passerelle SIMULÉE : aucun argent ne circule. Vérifie la carte comme une vraie passerelle (algorithme de Luhn,
 * date d'expiration, CVV) et accepte toute carte valide, sauf les cartes de test ci-dessous.
 * <ul>
 *   <li>4242 4242 4242 4242 : acceptée</li>
 *   <li>4000 0000 0000 0002 : refusée (carte refusée par la banque)</li>
 *   <li>4000 0000 0000 9995 : refusée (solde insuffisant)</li>
 * </ul>
 */
@Component
public class SimulatedPaymentGateway implements PaymentGateway {

    private static final String DECLINED_CARD = "4000000000000002";
    private static final String INSUFFICIENT_FUNDS_CARD = "4000000000009995";

    private final SecureRandom random = new SecureRandom();
    private final Clock clock;

    public SimulatedPaymentGateway(Clock clock) {
        this.clock = clock;
    }

    @Override
    public PaymentResult charge(CardPayment payment) {
        String number = payment.cardNumber() == null ? "" : payment.cardNumber().replaceAll("[\\s-]", "");
        if (!number.matches("\\d{13,19}") || !luhn(number)) {
            return PaymentResult.declined("INVALID_CARD", "Numéro de carte invalide");
        }
        YearMonth expiry = parseExpiry(payment.expiry());
        if (expiry == null) {
            return PaymentResult.declined("INVALID_EXPIRY", "Date d'expiration invalide (format MM/AA)");
        }
        if (expiry.isBefore(YearMonth.now(clock))) {
            return PaymentResult.declined("CARD_EXPIRED", "Carte expirée");
        }
        if (payment.cvv() == null || !payment.cvv().matches("\\d{3}")) {
            return PaymentResult.declined("INVALID_CVV", "Code de sécurité (CVV) invalide : 3 chiffres");
        }
        if (number.equals(DECLINED_CARD)) {
            return PaymentResult.declined("CARD_DECLINED", "Paiement refusé par la banque");
        }
        if (number.equals(INSUFFICIENT_FUNDS_CARD)) {
            return PaymentResult.declined("INSUFFICIENT_FUNDS", "Solde insuffisant");
        }
        byte[] id = new byte[5];
        random.nextBytes(id);
        return PaymentResult.approved("SIM-" + HexFormat.of().withUpperCase().formatHex(id),
                number.substring(number.length() - 4));
    }

    static boolean luhn(String digits) {
        int sum = 0;
        boolean dbl = false;
        for (int i = digits.length() - 1; i >= 0; i--) {
            int d = digits.charAt(i) - '0';
            if (dbl) {
                d *= 2;
                if (d > 9) {
                    d -= 9;
                }
            }
            sum += d;
            dbl = !dbl;
        }
        return sum % 10 == 0;
    }

    private static YearMonth parseExpiry(String value) {
        if (value == null || !value.trim().matches("(0[1-9]|1[0-2])/\\d{2}")) {
            return null;
        }
        String[] parts = value.trim().split("/");
        return YearMonth.of(2000 + Integer.parseInt(parts[1]), Integer.parseInt(parts[0]));
    }
}
