package com.healthcare.auth;

import com.healthcare.common.exception.ApiException;
import org.springframework.http.HttpStatus;

/**
 * Connexion refusée tant que l'adresse e-mail n'est pas confirmée. Levée seulement après
 * vérification du mot de passe : ne révèle donc pas qu'un e-mail est inscrit.
 */
public class EmailNotVerifiedException extends ApiException {

    public EmailNotVerifiedException() {
        super(HttpStatus.FORBIDDEN, "EMAIL_NOT_VERIFIED",
                "Adresse e-mail non vérifiée. Saisissez le code reçu par e-mail.");
    }
}
