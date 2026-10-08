package com.healthcare.auth.dto;

import jakarta.validation.constraints.*;

import java.time.LocalDate;

public record RegisterPatientRequest(
        @NotBlank @Email @Size(max = 150) String email,
        @NotBlank @Pattern(regexp = PasswordPolicy.REGEX, message = PasswordPolicy.MESSAGE) String password,
        @NotBlank @Size(max = 80) String firstName,
        @NotBlank @Size(max = 80) String lastName,
        @Size(max = 30) @Pattern(regexp = "^[+0-9 ]*$", message = "Numéro de téléphone invalide") String phone,
        @Past LocalDate dateOfBirth
) {
}
