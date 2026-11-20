package com.healthcare.billing;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * {@code cnamRatePercent} : part prise en charge par la CNAM (taux SIMULÉ, identique pour tous les actes).
 */
@ConfigurationProperties(prefix = "app.billing")
public record BillingProperties(Integer cnamRatePercent) {
    public BillingProperties {
        if (cnamRatePercent == null) {
            cnamRatePercent = 70;
        }
        if (cnamRatePercent < 0 || cnamRatePercent > 100) {
            throw new IllegalArgumentException("app.billing.cnam-rate-percent doit être entre 0 et 100");
        }
    }
}
