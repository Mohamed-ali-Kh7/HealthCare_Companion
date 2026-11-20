package com.healthcare.messaging.call;

import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.socket.config.annotation.EnableWebSocket;
import org.springframework.web.socket.config.annotation.WebSocketConfigurer;
import org.springframework.web.socket.config.annotation.WebSocketHandlerRegistry;

import java.util.List;

@Configuration
@EnableWebSocket
@RequiredArgsConstructor
public class CallWebSocketConfig implements WebSocketConfigurer {

    private final CallSignalingHandler handler;
    private final CallHandshakeInterceptor handshakeInterceptor;

    @Value("${app.cors.allowed-origins}")
    private List<String> allowedOrigins;

    @Override
    public void registerWebSocketHandlers(WebSocketHandlerRegistry registry) {
        // Les applications mobiles n'envoient pas d'en-tête Origin : seules les pages web sont filtrées.
        registry.addHandler(handler, "/ws/calls")
                .addInterceptors(handshakeInterceptor)
                .setAllowedOriginPatterns(allowedOrigins.toArray(String[]::new));
    }
}
