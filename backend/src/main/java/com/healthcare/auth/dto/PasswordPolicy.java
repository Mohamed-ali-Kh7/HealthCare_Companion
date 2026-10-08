package com.healthcare.auth.dto;

/** Politique de mot de passe partagée par toutes les validations. BCrypt tronque au-delà de 72 octets. */
public final class PasswordPolicy {

    public static final String REGEX = "^(?=.*[A-Za-z])(?=.*\\d).{8,72}$";
    public static final String MESSAGE = "Le mot de passe doit contenir 8 à 72 caractères, dont au moins une lettre et un chiffre";

    private PasswordPolicy() {
    }
}
