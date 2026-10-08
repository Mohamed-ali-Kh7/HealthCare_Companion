package com.healthcare.patient.dto;

import com.healthcare.patient.Patient;

import java.time.LocalDate;

public record PatientResponse(
        Long id,
        String email,
        String firstName,
        String lastName,
        String phone,
        LocalDate dateOfBirth,
        String bloodGroup,
        String allergies
) {
    public static PatientResponse from(Patient p) {
        return new PatientResponse(p.getId(), p.getUser().getEmail(), p.getFirstName(), p.getLastName(),
                p.getPhone(), p.getDateOfBirth(), p.getBloodGroup(), p.getAllergies());
    }
}
