package com.healthcare.telemonitoring.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.util.List;

/** Envoi groupé par le service d'arrière-plan Flutter (économise batterie et réseau). */
public record SensorBatchRequest(
        @NotEmpty @Size(max = 500) List<@Valid @NotNull SensorReadingRequest> readings
) {
}
