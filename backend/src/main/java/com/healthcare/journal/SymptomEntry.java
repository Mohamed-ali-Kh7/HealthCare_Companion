package com.healthcare.journal;

import com.healthcare.common.BaseEntity;
import com.healthcare.patient.Patient;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.LocalDate;

/**
 * Journal de symptômes : une entrée par patient et par jour (une nouvelle saisie du même jour la remplace).
 * Chaque mesure est facultative : le patient note ce qu'il souhaite.
 */
@Entity
@Table(name = "symptom_entries",
        uniqueConstraints = @UniqueConstraint(name = "uk_symptom_patient_date", columnNames = {"patient_id", "entry_date"}))
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class SymptomEntry extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "patient_id", nullable = false)
    private Patient patient;

    @Column(name = "entry_date", nullable = false)
    private LocalDate entryDate;

    /** Douleur : 0 (aucune) à 10 (maximale), échelle numérique standard. */
    private Integer pain;

    /** Humeur : 1 (très mauvaise) à 5 (très bonne). */
    private Integer mood;

    /** Heures de sommeil la nuit précédente. */
    @Column(name = "sleep_hours")
    private Double sleepHours;

    /** Température corporelle (°C) : fièvre à partir de 38. */
    private Double temperature;

    @Column(length = 500)
    private String note;

    public SymptomEntry(Patient patient, LocalDate entryDate) {
        this.patient = patient;
        this.entryDate = entryDate;
    }

    public void update(Integer pain, Integer mood, Double sleepHours, Double temperature, String note) {
        this.pain = pain;
        this.mood = mood;
        this.sleepHours = sleepHours;
        this.temperature = temperature;
        this.note = note;
    }
}
