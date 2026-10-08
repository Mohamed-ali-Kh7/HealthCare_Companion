package com.healthcare.auth.dto;

import com.healthcare.user.dto.UserResponse;

/** Réponse de login / inscription patient. expiresIn est en secondes. */
public record AuthResponse(String accessToken, String tokenType, long expiresIn, UserResponse user) {

    public static AuthResponse bearer(String token, long expiresIn, UserResponse user) {
        return new AuthResponse(token, "Bearer", expiresIn, user);
    }
}
