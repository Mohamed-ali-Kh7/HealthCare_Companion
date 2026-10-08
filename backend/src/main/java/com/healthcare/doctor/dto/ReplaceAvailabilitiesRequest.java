package com.healthcare.doctor.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.util.List;

/** Planning hebdomadaire complet : {"availabilities":[{...},{...}]} */
public record ReplaceAvailabilitiesRequest(
        @NotNull @Size(max = 50) List<@Valid @NotNull AvailabilityRequest> availabilities
) {
}
