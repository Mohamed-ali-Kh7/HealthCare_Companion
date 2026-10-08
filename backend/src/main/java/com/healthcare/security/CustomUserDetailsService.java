package com.healthcare.security;

import com.healthcare.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Optional;

/**
 * Infrastructure transverse : seule dérogation à la règle "un module n'utilise pas
 * le repository d'un autre module".
 */
@Service
@RequiredArgsConstructor
public class CustomUserDetailsService implements UserDetailsService {

    private final UserRepository userRepository;

    /** Utilisé par l'AuthenticationManager lors du login. */
    @Override
    @Transactional(readOnly = true)
    public UserDetails loadUserByUsername(String email) {
        return userRepository.findByEmail(email.trim().toLowerCase())
                .map(SecurityUser::from)
                .orElseThrow(() -> new UsernameNotFoundException("Utilisateur introuvable"));
    }

    /** Utilisé par le filtre JWT à chaque requête : rôle et statut toujours à jour. */
    @Transactional(readOnly = true)
    public Optional<SecurityUser> loadById(Long id) {
        return userRepository.findById(id).map(SecurityUser::from);
    }
}
