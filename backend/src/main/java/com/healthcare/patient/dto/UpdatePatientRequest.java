package com.healthcare.patient.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Past;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

import java.time.LocalDate;

public record UpdatePatientRequest(
        @NotBlank @Size(max = 80) String firstName,
        @NotBlank @Size(max = 80) String lastName,
        @Size(max = 30) @Pattern(regexp = "^[+0-9 ]*$", message = "Numéro de téléphone invalide") String phone,
        @Past LocalDate dateOfBirth,
        @Pattern(regexp = "^(A|B|AB|O)[+-]$|^$", message = "Groupe sanguin invalide (ex : A+, O-)") String bloodGroup,
        @Size(max = 500) String allergies
) {
}
