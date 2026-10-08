package com.healthcare.medication.dto;

import com.healthcare.medication.Medication;
import com.healthcare.medicine.dto.MedicineResponse;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;

public record MedicationResponse(
        Long id,
        MedicineResponse medicine,
        String actualDosage,
        int timesPerDay,
        LocalDate startDate,
        LocalDate endDate,
        List<LocalTime> reminderTimes,
        boolean active,
        boolean ongoing,
        boolean fromPrescription
) {
    public static MedicationResponse from(Medication m, LocalDate today) {
        return new MedicationResponse(
                m.getId(),
                MedicineResponse.from(m.getMedicine()),
                m.getActualDosage(),
                m.getTimesPerDay(),
                m.getStartDate(),
                m.getEndDate(),
                m.getReminderTimes().stream().sorted().toList(),
                m.isActive(),
                m.isOngoing(today),
                m.getPrescriptionItem() != null);
    }
}
