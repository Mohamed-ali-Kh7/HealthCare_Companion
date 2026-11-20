package com.healthcare.doctor.dto;

import com.healthcare.doctor.Doctor;
import com.healthcare.speciality.dto.SpecialityResponse;

import java.time.LocalDate;
import java.time.ZoneId;

/** {@code away} : absence en cours (une absence dont la date de retour est passée n'est plus signalée). */
public record DoctorResponse(
        Long id,
        String firstName,
        String lastName,
        String phone,
        String address,
        String bio,
        int consultationDurationMinutes,
        SpecialityResponse speciality,
        boolean away,
        String awayMessage,
        LocalDate awayUntil
) {
    private static final ZoneId ZONE = ZoneId.of("Africa/Tunis");

    public static DoctorResponse from(Doctor d) {
        boolean away = d.isAwayOn(LocalDate.now(ZONE));
        return new DoctorResponse(d.getId(), d.getFirstName(), d.getLastName(), d.getPhone(),
                d.getAddress(), d.getBio(), d.getConsultationDurationMinutes(),
                SpecialityResponse.from(d.getSpeciality()),
                away, away ? d.getAwayMessage() : null, away ? d.getAwayUntil() : null);
    }
}
