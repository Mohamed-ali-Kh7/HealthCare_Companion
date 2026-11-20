package com.healthcare.messaging;

/**
 * Un patient a écrit à un médecin absent : l'assistant santé peut lui répondre automatiquement.
 * Publié après l'enregistrement du message ; traité après la validation de la transaction.
 */
public record PatientWroteToAwayDoctorEvent(Long patientUserId, String patientEmail, Long doctorId) {
}
