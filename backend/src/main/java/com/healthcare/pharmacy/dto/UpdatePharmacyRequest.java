package com.healthcare.pharmacy.dto;

import jakarta.validation.constraints.*;

public record UpdatePharmacyRequest(
        @NotBlank @Size(max = 120) String name,
        @NotBlank @Size(max = 255) String address,
        @Size(max = 30) @Pattern(regexp = "^[+0-9 ]*$", message = "Numéro de téléphone invalide") String phone,
        @NotNull @DecimalMin("-90.0") @DecimalMax("90.0") Double latitude,
        @NotNull @DecimalMin("-180.0") @DecimalMax("180.0") Double longitude,
        @Size(max = 120) String openingHours,
        Boolean onDuty
) {
}
