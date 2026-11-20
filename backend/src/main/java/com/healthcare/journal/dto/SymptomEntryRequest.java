package com.healthcare.journal.dto;

import jakarta.validation.constraints.*;

import java.time.LocalDate;

/**
 * {"date":"2026-11-13","pain":4,"mood":3,"sleepHours":6.5,"temperature":38.2,"note":"Maux de tête le soir"}
 * Toutes les mesures sont facultatives, mais au moins une doit être renseignée (vérifié par le service).
 */
public record SymptomEntryRequest(
        @NotNull LocalDate date,
        @Min(0) @Max(10) Integer pain,
        @Min(1) @Max(5) Integer mood,
        @DecimalMin("0") @DecimalMax("24") Double sleepHours,
        @DecimalMin("34") @DecimalMax("43") Double temperature,
        @Size(max = 500) String note
) {
}
