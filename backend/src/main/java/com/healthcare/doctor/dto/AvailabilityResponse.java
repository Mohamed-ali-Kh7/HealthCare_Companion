package com.healthcare.doctor.dto;

import com.healthcare.doctor.DoctorAvailability;

import java.time.DayOfWeek;
import java.time.LocalTime;

public record AvailabilityResponse(Long id, DayOfWeek dayOfWeek, LocalTime startTime, LocalTime endTime) {

    public static AvailabilityResponse from(DoctorAvailability a) {
        return new AvailabilityResponse(a.getId(), a.getDayOfWeek(), a.getStartTime(), a.getEndTime());
    }
}
