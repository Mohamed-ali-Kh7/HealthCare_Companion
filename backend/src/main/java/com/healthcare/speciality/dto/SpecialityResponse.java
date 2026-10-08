package com.healthcare.speciality.dto;

import com.healthcare.speciality.Speciality;

public record SpecialityResponse(Long id, String name, String description) {

    public static SpecialityResponse from(Speciality s) {
        return new SpecialityResponse(s.getId(), s.getName(), s.getDescription());
    }
}
