package com.healthcare.auth.dto;

import com.healthcare.user.dto.UserResponse;

/** Réponse de login / inscription patient. expiresIn est en secondes. */
public record AuthResponse(String accessToken, String tokenType, long expiresIn, UserResponse user) {

    public static AuthResponse bearer(String token, long expiresIn, UserResponse user) {
        return new AuthResponse(token, "Bearer", expiresIn, user);
    }

    /**
     * Pas de session : e-mail à vérifier (user.emailVerified = false)
     * ou compte en attente de validation par un administrateur (user.enabled = false).
     */
    public static AuthResponse pending(UserResponse user) {
        return new AuthResponse(null, null, 0, user);
    }

    public boolean hasSession() {
        return accessToken != null;
    }
}
