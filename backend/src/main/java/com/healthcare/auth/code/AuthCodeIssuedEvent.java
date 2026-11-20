package com.healthcare.auth.code;

/** Publié quand un code est créé : l'e-mail part après validation de la transaction. */
public record AuthCodeIssuedEvent(String email, CodePurpose purpose, String code, int ttlMinutes) {

    @Override
    public String toString() { // jamais le code dans les logs
        return "AuthCodeIssuedEvent[email=" + email + ", purpose=" + purpose + "]";
    }
}
