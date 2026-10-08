package com.healthcare.common.exception;

import org.springframework.http.HttpStatus;

/** Conflit avec l'état actuel des données (ex : email déjà utilisé). */
public class ConflictException extends ApiException {

    public ConflictException(String code, String message) {
        super(HttpStatus.CONFLICT, code, message);
    }
}
