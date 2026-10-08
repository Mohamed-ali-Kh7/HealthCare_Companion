package com.healthcare.common.exception;

import org.springframework.http.HttpStatus;

/**
 * Requête bien formée mais interdite par une règle métier
 * (ex : annuler un rendez-vous déjà terminé).
 */
public class BusinessRuleException extends ApiException {

    public BusinessRuleException(String code, String message) {
        super(HttpStatus.UNPROCESSABLE_ENTITY, code, message);
    }
}
