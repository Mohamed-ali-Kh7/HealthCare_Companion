package com.healthcare.telemonitoring.dto;

import java.time.Instant;

/** Point d'une série temporelle. */
public record SensorPointResponse(Instant recordedAt, double value) {
}
