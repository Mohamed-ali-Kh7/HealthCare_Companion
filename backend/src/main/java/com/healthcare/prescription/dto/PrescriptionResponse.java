package com.healthcare.prescription.dto;

import com.healthcare.common.dto.PersonSummary;
import com.healthcare.medicine.dto.MedicineResponse;
import com.healthcare.prescription.Prescription;
import com.healthcare.prescription.PrescriptionItem;

import java.time.LocalDate;
import java.util.List;

public record PrescriptionResponse(
        Long id,
        LocalDate prescriptionDate,
        String notes,
        PersonSummary patient,
        DoctorInfo doctor,
        List<Item> items
) {
    public record DoctorInfo(Long id, String firstName, String lastName, String specialityName) {
    }

    public record Item(Long id, MedicineResponse medicine, String prescribedDosage,
                       int timesPerDay, int durationDays, String instructions) {

        static Item from(PrescriptionItem i) {
            return new Item(i.getId(), MedicineResponse.from(i.getMedicine()), i.getPrescribedDosage(),
                    i.getTimesPerDay(), i.getDurationDays(), i.getInstructions());
        }
    }

    public static PrescriptionResponse from(Prescription p) {
        return new PrescriptionResponse(
                p.getId(),
                p.getPrescriptionDate(),
                p.getNotes(),
                new PersonSummary(p.getPatient().getId(), p.getPatient().getFirstName(), p.getPatient().getLastName()),
                new DoctorInfo(p.getDoctor().getId(), p.getDoctor().getFirstName(), p.getDoctor().getLastName(),
                        p.getDoctor().getSpeciality().getName()),
                p.getItems().stream().map(Item::from).toList());
    }
}
