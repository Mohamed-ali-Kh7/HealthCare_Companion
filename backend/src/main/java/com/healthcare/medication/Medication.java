package com.healthcare.medication;

import com.healthcare.common.BaseEntity;
import com.healthcare.medicine.Medicine;
import com.healthcare.patient.Patient;
import com.healthcare.prescription.PrescriptionItem;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.List;

/**
 * Carnet de suivi : traitement que le patient suit au quotidien.
 * Issu d'une ligne d'ordonnance (prescriptionItem renseigné) ou ajouté manuellement.
 * Les heures de rappel sont planifiées en notifications locales par l'application mobile.
 */
@Entity
@Table(name = "medications",
        uniqueConstraints = @UniqueConstraint(name = "uk_medication_prescription_item",
                columnNames = "prescription_item_id"),
        indexes = @Index(name = "idx_medication_patient", columnList = "patient_id"))
@Getter
@Setter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Medication extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "patient_id", nullable = false)
    private Patient patient;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "medicine_id", nullable = false)
    private Medicine medicine;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "prescription_item_id")
    private PrescriptionItem prescriptionItem;

    @Column(name = "actual_dosage", nullable = false, length = 60)
    private String actualDosage;

    @Column(name = "times_per_day", nullable = false)
    private int timesPerDay;

    @Column(name = "start_date", nullable = false)
    private LocalDate startDate;

    /** null = traitement au long cours. */
    @Column(name = "end_date")
    private LocalDate endDate;

    @ElementCollection
    @CollectionTable(name = "medication_reminder_times",
            joinColumns = @JoinColumn(name = "medication_id"))
    @Column(name = "reminder_time", nullable = false)
    private List<LocalTime> reminderTimes = new ArrayList<>();

    @Column(nullable = false)
    private boolean active = true;

    public Medication(Patient patient, Medicine medicine, PrescriptionItem prescriptionItem,
                      String actualDosage, int timesPerDay, LocalDate startDate, LocalDate endDate,
                      List<LocalTime> reminderTimes) {
        this.patient = patient;
        this.medicine = medicine;
        this.prescriptionItem = prescriptionItem;
        this.actualDosage = actualDosage;
        this.timesPerDay = timesPerDay;
        this.startDate = startDate;
        this.endDate = endDate;
        this.reminderTimes = new ArrayList<>(reminderTimes);
    }

    public void replaceReminderTimes(List<LocalTime> times) {
        reminderTimes.clear();
        reminderTimes.addAll(times);
    }

    public boolean isOngoing(LocalDate today) {
        return active && !today.isBefore(startDate) && (endDate == null || !today.isAfter(endDate));
    }
}
