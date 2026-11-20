package com.healthcare.prescription.dto;

/** Nombre de prescriptions d'un médicament (statistiques médecin). */
public record MedicineUsage(Long medicineId, String name, String strength, long count) {
}
