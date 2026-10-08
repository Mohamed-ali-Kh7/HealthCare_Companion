package com.healthcare.prescription.dto;

import jakarta.validation.constraints.*;

public record PrescriptionItemRequest(
        @NotNull Long medicineId,
        @NotBlank @Size(max = 60) String prescribedDosage,
        @NotNull @Min(1) @Max(6) Integer timesPerDay,
        @NotNull @Min(1) @Max(365) Integer durationDays,
        @Size(max = 500) String instructions
) {
}
