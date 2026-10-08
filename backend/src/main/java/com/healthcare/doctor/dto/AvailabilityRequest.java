package com.healthcare.doctor.dto;

import jakarta.validation.constraints.NotNull;

import java.time.DayOfWeek;
import java.time.LocalTime;

/** Exemple JSON : {"dayOfWeek":"MONDAY","startTime":"09:00","endTime":"12:00"} */
public record AvailabilityRequest(
        @NotNull DayOfWeek dayOfWeek,
        @NotNull LocalTime startTime,
        @NotNull LocalTime endTime
) {
}
