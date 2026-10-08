package com.healthcare.user;

import com.healthcare.common.dto.PageResponse;
import com.healthcare.common.exception.BusinessRuleException;
import com.healthcare.common.exception.ConflictException;
import com.healthcare.common.exception.ResourceNotFoundException;
import com.healthcare.user.dto.UserResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.EnumMap;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class UserService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    /** Crée le compte d'authentification. Le profil métier est créé par le module concerné. */
    @Transactional
    public User createUser(String email, String rawPassword, Role role, boolean enabled) {
        String normalized = email.trim().toLowerCase();
        if (userRepository.existsByEmail(normalized)) {
            throw new ConflictException("EMAIL_ALREADY_USED", "Un compte existe déjà avec cet email");
        }
        return userRepository.save(new User(normalized, passwordEncoder.encode(rawPassword), role, enabled));
    }

    @Transactional(readOnly = true)
    public User getEntity(Long id) {
        return userRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Utilisateur", id));
    }

    @Transactional(readOnly = true)
    public UserResponse getById(Long id) {
        return UserResponse.from(getEntity(id));
    }

    @Transactional(readOnly = true)
    public PageResponse<UserResponse> search(String q, Role role, Boolean enabled, Pageable pageable) {
        String query = (q == null || q.isBlank()) ? null : q.trim();
        return PageResponse.of(userRepository.search(query, role, enabled, pageable), UserResponse::from);
    }

    /** Activation / désactivation par l'admin (validation des médecins et pharmaciens incluse). */
    @Transactional
    public UserResponse setEnabled(Long targetId, boolean enabled, Long currentAdminId) {
        if (targetId.equals(currentAdminId) && !enabled) {
            throw new BusinessRuleException("CANNOT_DISABLE_SELF",
                    "Un administrateur ne peut pas désactiver son propre compte");
        }
        User user = getEntity(targetId);
        user.setEnabled(enabled);
        return UserResponse.from(user);
    }

    @Transactional
    public void changePassword(Long userId, String currentPassword, String newPassword) {
        User user = getEntity(userId);
        if (!passwordEncoder.matches(currentPassword, user.getPassword())) {
            throw new BusinessRuleException("WRONG_PASSWORD", "Mot de passe actuel incorrect");
        }
        user.setPassword(passwordEncoder.encode(newPassword));
    }

    @Transactional(readOnly = true)
    public Map<Role, Long> countByRole() {
        Map<Role, Long> counts = new EnumMap<>(Role.class);
        for (Role role : Role.values()) {
            counts.put(role, userRepository.countByRole(role));
        }
        return counts;
    }

    @Transactional(readOnly = true)
    public long countDisabled() {
        return userRepository.countByEnabledFalse();
    }
}
