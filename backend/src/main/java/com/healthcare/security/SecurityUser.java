package com.healthcare.security;

import com.healthcare.user.Role;
import com.healthcare.user.User;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;

import java.util.Collection;
import java.util.List;

/**
 * Adaptateur entre l'entité User et Spring Security.
 * Dans un contrôleur : {@code @AuthenticationPrincipal SecurityUser me} puis {@code me.id()}.
 */
public record SecurityUser(Long id, String email, String passwordHash, Role role, boolean enabled)
        implements UserDetails {

    public static SecurityUser from(User user) {
        return new SecurityUser(user.getId(), user.getEmail(), user.getPassword(),
                user.getRole(), user.isEnabled());
    }

    public boolean hasRole(Role expected) {
        return role == expected;
    }

    @Override
    public Collection<? extends GrantedAuthority> getAuthorities() {
        return List.of(new SimpleGrantedAuthority("ROLE_" + role.name()));
    }

    @Override
    public String getPassword() {
        return passwordHash;
    }

    @Override
    public String getUsername() {
        return email;
    }

    @Override
    public boolean isEnabled() {
        return enabled;
    }

    @Override
    public String toString() { // ne jamais exposer le hash dans les logs
        return "SecurityUser[id=" + id + ", role=" + role + "]";
    }
}
