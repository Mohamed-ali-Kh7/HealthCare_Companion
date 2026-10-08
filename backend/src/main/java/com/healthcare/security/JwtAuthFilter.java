package com.healthcare.security;

import io.jsonwebtoken.ExpiredJwtException;
import io.jsonwebtoken.JwtException;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpHeaders;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContext;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

/**
 * Identifie l'utilisateur à partir du header "Authorization: Bearer ...".
 * Ne bloque jamais : c'est SecurityConfig qui décide si la route exige une authentification.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class JwtAuthFilter extends OncePerRequestFilter {

    /** Lu par RestAuthenticationEntryPoint pour préciser l'erreur 401. */
    public static final String JWT_ERROR_ATTR = "jwt_error";
    private static final String BEARER_PREFIX = "Bearer ";

    private final JwtService jwtService;
    private final CustomUserDetailsService userDetailsService;

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain chain) throws ServletException, IOException {

        String header = request.getHeader(HttpHeaders.AUTHORIZATION);
        if (header == null || !header.startsWith(BEARER_PREFIX)) {
            chain.doFilter(request, response);
            return;
        }

        try {
            Long userId = jwtService.extractUserId(header.substring(BEARER_PREFIX.length()));
            userDetailsService.loadById(userId)
                    .filter(SecurityUser::isEnabled)
                    .ifPresentOrElse(
                            user -> authenticate(user, request),
                            () -> request.setAttribute(JWT_ERROR_ATTR, "ACCOUNT_UNAVAILABLE"));
        } catch (ExpiredJwtException e) {
            request.setAttribute(JWT_ERROR_ATTR, "TOKEN_EXPIRED");
        } catch (JwtException | IllegalArgumentException e) {
            log.debug("JWT rejeté : {}", e.getMessage());
            request.setAttribute(JWT_ERROR_ATTR, "TOKEN_INVALID");
        }

        chain.doFilter(request, response);
    }

    private void authenticate(SecurityUser user, HttpServletRequest request) {
        var auth = UsernamePasswordAuthenticationToken.authenticated(user, null, user.getAuthorities());
        auth.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));

        SecurityContext context = SecurityContextHolder.createEmptyContext();
        context.setAuthentication(auth);
        SecurityContextHolder.setContext(context);
    }
}
