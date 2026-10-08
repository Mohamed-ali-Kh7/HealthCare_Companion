package com.healthcare.common.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.time.Clock;
import java.time.ZoneId;

/**
 * Horloge injectable : toutes les règles temporelles (rendez-vous dans le futur,
 * créneaux, résumés journaliers) utilisent ce fuseau, indépendamment du serveur.
 * Remplaçable par une horloge fixe dans les tests.
 */
@Configuration
public class TimeConfig {

    @Bean
    public Clock clock(@Value("${app.timezone:Africa/Tunis}") String zone) {
        return Clock.system(ZoneId.of(zone));
    }
}
