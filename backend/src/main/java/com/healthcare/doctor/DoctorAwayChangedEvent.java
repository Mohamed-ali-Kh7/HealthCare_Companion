package com.healthcare.doctor;

import java.time.LocalDate;

/** Le médecin passe absent ou redevient disponible : ses patients sont prévenus en direct (messagerie). */
public record DoctorAwayChangedEvent(Long doctorId, String doctorName, boolean away, String message, LocalDate until) {
}
