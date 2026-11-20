package com.healthcare.messaging.call;

import com.healthcare.security.CustomUserDetailsService;
import com.healthcare.security.JwtService;
import com.healthcare.security.SecurityUser;
import com.healthcare.user.Role;
import io.jsonwebtoken.JwtException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.server.ServerHttpRequest;
import org.springframework.http.server.ServerHttpResponse;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.WebSocketHandler;
import org.springframework.web.socket.server.HandshakeInterceptor;
import org.springframework.web.util.UriComponentsBuilder;

import java.util.Map;
import java.util.Optional;

/**
 * Authentifie la connexion WebSocket : les navigateurs ne peuvent pas envoyer d'en-tête
 * Authorization sur un WebSocket, le JWT est donc passé en paramètre {@code ?token=}.
 * Mêmes vérifications que JwtAuthFilter (signature, expiration, compte actif) ; réservé aux patients et médecins.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class CallHandshakeInterceptor implements HandshakeInterceptor {

    public static final String USER_ATTR = "user";

    private final JwtService jwtService;
    private final CustomUserDetailsService userDetailsService;

    @Override
    public boolean beforeHandshake(ServerHttpRequest request, ServerHttpResponse response,
                                   WebSocketHandler wsHandler, Map<String, Object> attributes) {
        String token = UriComponentsBuilder.fromUri(request.getURI()).build().getQueryParams().getFirst("token");
        Optional<SecurityUser> user = Optional.empty();
        if (token != null && !token.isBlank()) {
            try {
                user = userDetailsService.loadById(jwtService.extractUserId(token))
                        .filter(SecurityUser::isEnabled)
                        // Pharmaciens et ambulanciers : notifications uniquement (les appels leur restent refusés)
                        .filter(u -> u.hasRole(Role.PATIENT) || u.hasRole(Role.DOCTOR)
                                || u.hasRole(Role.PHARMACIST) || u.hasRole(Role.AMBULANCE_COMPANY));
            } catch (JwtException | IllegalArgumentException e) {
                log.debug("Connexion d'appel refusée : {}", e.getMessage());
            }
        }
        if (user.isEmpty()) {
            response.setStatusCode(HttpStatus.UNAUTHORIZED);
            return false;
        }
        attributes.put(USER_ATTR, user.get());
        return true;
    }

    @Override
    public void afterHandshake(ServerHttpRequest request, ServerHttpResponse response,
                               WebSocketHandler wsHandler, Exception exception) {
        // rien
    }
}
