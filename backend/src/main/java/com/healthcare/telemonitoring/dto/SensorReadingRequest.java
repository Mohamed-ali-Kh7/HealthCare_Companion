package com.healthcare.telemonitoring.dto;

import com.healthcare.telemonitoring.SensorType;
import jakarta.validation.constraints.NotNull;

import java.time.Instant;

/** Exemple : {"type":"STEPS","value":4250,"recordedAt":"2026-10-07T18:00:00Z"} */
public record SensorReadingRequest(
        @NotNull SensorType type,
        @NotNull Double value,
        @NotNull Instant recordedAt
) {
}
