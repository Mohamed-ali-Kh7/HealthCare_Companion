package com.healthcare.prescription;

import com.healthcare.common.BaseEntity;
import com.healthcare.doctor.Doctor;
import com.healthcare.patient.Patient;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

/** Ordonnance : en-tête (patient, médecin, date) + lignes (PrescriptionItem). Non modifiable une fois émise. */
@Entity
@Table(name = "prescriptions", indexes = {
        @Index(name = "idx_prescription_patient", columnList = "patient_id"),
        @Index(name = "idx_prescription_doctor", columnList = "doctor_id")
})
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Prescription extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "patient_id", nullable = false)
    private Patient patient;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "doctor_id", nullable = false)
    private Doctor doctor;

    @Column(name = "prescription_date", nullable = false)
    private LocalDate prescriptionDate;

    @Column(length = 1000)
    private String notes;

    @OneToMany(mappedBy = "prescription", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("id ASC")
    private List<PrescriptionItem> items = new ArrayList<>();

    public Prescription(Patient patient, Doctor doctor, LocalDate prescriptionDate, String notes) {
        this.patient = patient;
        this.doctor = doctor;
        this.prescriptionDate = prescriptionDate;
        this.notes = notes;
    }

    /** Maintient les deux côtés de la relation bidirectionnelle. */
    public void addItem(PrescriptionItem item) {
        item.attachTo(this);
        items.add(item);
    }
}
