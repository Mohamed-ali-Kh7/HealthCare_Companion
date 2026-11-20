package com.healthcare.journal.dto;

import com.healthcare.journal.SymptomEntry;

import java.time.Instant;
import java.time.LocalDate;

public record SymptomEntryResponse(
        Long id,
        LocalDate date,
        Integer pain,
        Integer mood,
        Double sleepHours,
        Double temperature,
        String note,
        Instant updatedAt
) {
    public static SymptomEntryResponse from(SymptomEntry e) {
        return new SymptomEntryResponse(e.getId(), e.getEntryDate(), e.getPain(), e.getMood(), e.getSleepHours(),
                e.getTemperature(), e.getNote(), e.getUpdatedAt());
    }
}
