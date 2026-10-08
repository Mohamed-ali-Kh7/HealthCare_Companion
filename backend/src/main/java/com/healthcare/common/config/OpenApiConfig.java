package com.healthcare.common.config;

import io.swagger.v3.oas.annotations.OpenAPIDefinition;
import io.swagger.v3.oas.annotations.enums.SecuritySchemeType;
import io.swagger.v3.oas.annotations.info.Info;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.security.SecurityScheme;
import org.springframework.context.annotation.Configuration;

/** Swagger UI : http://localhost:8080/swagger-ui.html (bouton "Authorize" pour coller le JWT). */
@Configuration
@OpenAPIDefinition(
        info = @Info(title = "HealthCare Companion API", version = "v1",
                description = "API REST de la plateforme e-santé HealthCare Companion"),
        security = @SecurityRequirement(name = "bearerAuth"))
@SecurityScheme(name = "bearerAuth", type = SecuritySchemeType.HTTP, scheme = "bearer", bearerFormat = "JWT")
public class OpenApiConfig {
}
