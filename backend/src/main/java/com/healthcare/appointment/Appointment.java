package com.healthcare.appointment;

import com.healthcare.common.BaseEntity;
import com.healthcare.common.exception.BusinessRuleException;
import com.healthcare.doctor.Doctor;
import com.healthcare.patient.Patient;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * Rendez-vous. Les transitions de statut sont encapsulées ici (pas de setStatus public) :
 * PENDING → ACCEPTED | REJECTED | CANCELLED ; ACCEPTED → COMPLETED | CANCELLED.
 */
@Entity
@Table(name = "appointments", indexes = {
        @Index(name = "idx_appointment_doctor_date", columnList = "doctor_id, appointment_date"),
        @Index(name = "idx_appointment_patient", columnList = "patient_id")
})
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Appointment extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "patient_id", nullable = false)
    private Patient patient;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "doctor_id", nullable = false)
    private Doctor doctor;

    /** Heure locale du cabinet (fuseau app.timezone). */
    @Column(name = "appointment_date", nullable = false)
    private LocalDateTime appointmentDate;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private AppointmentStatus status = AppointmentStatus.PENDING;

    @Column(length = 500)
    private String reason;

    /** Motif de refus ou commentaire du médecin. */
    @Column(name = "doctor_note", length = 500)
    private String doctorNote;

    public Appointment(Patient patient, Doctor doctor, LocalDateTime appointmentDate, String reason) {
        this.patient = patient;
        this.doctor = doctor;
        this.appointmentDate = appointmentDate;
        this.reason = reason;
    }

    public void accept() {
        requireStatus(AppointmentStatus.PENDING);
        status = AppointmentStatus.ACCEPTED;
    }

    public void reject(String note) {
        requireStatus(AppointmentStatus.PENDING);
        status = AppointmentStatus.REJECTED;
        doctorNote = note;
    }

    public void complete(String note) {
        requireStatus(AppointmentStatus.ACCEPTED);
        status = AppointmentStatus.COMPLETED;
        if (note != null && !note.isBlank()) {
            doctorNote = note;
        }
    }

    public void cancel(LocalDateTime now) {
        if (!AppointmentStatus.BLOCKING_SLOT.contains(status)) {
            throw new BusinessRuleException("INVALID_STATUS_TRANSITION",
                    "Seul un rendez-vous en attente ou accepté peut être annulé");
        }
        if (!appointmentDate.isAfter(now)) {
            throw new BusinessRuleException("APPOINTMENT_IN_PAST", "Impossible d'annuler un rendez-vous passé");
        }
        status = AppointmentStatus.CANCELLED;
    }

    private void requireStatus(AppointmentStatus expected) {
        if (status != expected) {
            throw new BusinessRuleException("INVALID_STATUS_TRANSITION",
                    "Opération impossible : le rendez-vous est " + status);
        }
    }
}
