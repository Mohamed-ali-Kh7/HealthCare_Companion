package com.healthcare.common.exception;

import lombok.Getter;
import org.springframework.http.HttpStatus;

/** Exception métier portant son statut HTTP et un code stable lisible par le client. */
@Getter
public abstract class ApiException extends RuntimeException {

    private final HttpStatus status;
    private final String code;

    protected ApiException(HttpStatus status, String code, String message) {
        super(message);
        this.status = status;
        this.code = code;
    }
}
