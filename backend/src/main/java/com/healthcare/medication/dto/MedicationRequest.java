package com.healthcare.medication.dto;

import jakarta.validation.constraints.*;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;

/**
 * Ajout manuel ou modification d'un traitement du carnet.
 * medicineId est ignoré en modification. reminderTimes optionnel : généré depuis timesPerDay.
 */
public record MedicationRequest(
        Long medicineId,
        @NotBlank @Size(max = 60) String actualDosage,
        @NotNull @Min(1) @Max(6) Integer timesPerDay,
        @NotNull LocalDate startDate,
        LocalDate endDate,
        @Size(max = 6) List<@NotNull LocalTime> reminderTimes,
        Boolean active
) {
}
