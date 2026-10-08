package com.healthcare.doctor.dto;

import com.healthcare.doctor.Doctor;
import com.healthcare.speciality.dto.SpecialityResponse;

public record DoctorResponse(
        Long id,
        String firstName,
        String lastName,
        String phone,
        String address,
        String bio,
        int consultationDurationMinutes,
        SpecialityResponse speciality
) {
    public static DoctorResponse from(Doctor d) {
        return new DoctorResponse(d.getId(), d.getFirstName(), d.getLastName(), d.getPhone(),
                d.getAddress(), d.getBio(), d.getConsultationDurationMinutes(),
                SpecialityResponse.from(d.getSpeciality()));
    }
}
