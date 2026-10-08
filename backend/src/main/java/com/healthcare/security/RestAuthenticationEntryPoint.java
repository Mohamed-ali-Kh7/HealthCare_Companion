package com.healthcare.security;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.stereotype.Component;

import java.io.IOException;

/** 401 : route protégée appelée sans token valide. Le code précise la cause pour Flutter. */
@Component
@RequiredArgsConstructor
public class RestAuthenticationEntryPoint implements AuthenticationEntryPoint {

    private final ProblemResponseWriter writer;

    @Override
    public void commence(HttpServletRequest request, HttpServletResponse response,
                         AuthenticationException authException) throws IOException {

        Object jwtError = request.getAttribute(JwtAuthFilter.JWT_ERROR_ATTR);
        String code = jwtError != null ? jwtError.toString() : "AUTHENTICATION_REQUIRED";
        String detail = switch (code) {
            case "TOKEN_EXPIRED" -> "Session expirée, veuillez vous reconnecter";
            case "TOKEN_INVALID" -> "Token d'authentification invalide";
            case "ACCOUNT_UNAVAILABLE" -> "Compte désactivé ou supprimé";
            default -> "Authentification requise";
        };
        writer.write(request, response, HttpStatus.UNAUTHORIZED, code, detail);
    }
}
