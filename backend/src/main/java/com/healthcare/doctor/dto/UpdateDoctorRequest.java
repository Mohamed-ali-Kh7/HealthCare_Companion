package com.healthcare.doctor.dto;

import jakarta.validation.constraints.*;

public record UpdateDoctorRequest(
        @NotBlank @Size(max = 80) String firstName,
        @NotBlank @Size(max = 80) String lastName,
        @Size(max = 30) @Pattern(regexp = "^[+0-9 ]*$", message = "Numéro de téléphone invalide") String phone,
        @NotBlank @Size(max = 255) String address,
        @NotNull Long specialityId,
        @Size(max = 1000) String bio,
        @NotNull @Min(10) @Max(120) Integer consultationDurationMinutes
) {
}
