package com.healthcare.billing.payment;

import java.math.BigDecimal;

/**
 * Passerelle de paiement par carte. L'implémentation actuelle est simulée ({@link SimulatedPaymentGateway}) ;
 * une passerelle réelle (Konnect, Flouci, ClicToPay...) se branche en fournissant une autre implémentation.
 */
public interface PaymentGateway {

    PaymentResult charge(CardPayment payment);

    /** Données de carte : utilisées pour le paiement puis oubliées (jamais enregistrées). */
    record CardPayment(BigDecimal amount, String description, String holder, String cardNumber,
                       String expiry, String cvv) {
        @Override
        public String toString() {
            return "CardPayment[amount=" + amount + ", card=****]"; // jamais de numéro de carte dans les logs
        }
    }

    /** {@code reference} si accepté ; sinon {@code errorCode} et {@code message} lisible par le patient. */
    record PaymentResult(boolean approved, String reference, String cardLast4, String errorCode, String message) {
        public static PaymentResult approved(String reference, String last4) {
            return new PaymentResult(true, reference, last4, null, null);
        }

        public static PaymentResult declined(String code, String message) {
            return new PaymentResult(false, null, null, code, message);
        }
    }
}
