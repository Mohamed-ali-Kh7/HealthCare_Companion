package com.healthcare.user.dto;

import com.healthcare.user.Role;
import com.healthcare.user.User;

import java.time.Instant;

public record UserResponse(Long id, String email, Role role, boolean enabled, Instant createdAt) {

    public static UserResponse from(User user) {
        return new UserResponse(user.getId(), user.getEmail(), user.getRole(),
                user.isEnabled(), user.getCreatedAt());
    }
}
