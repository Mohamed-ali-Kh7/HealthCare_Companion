package com.healthcare.ambulance;

/**
 * Urgence : DISPATCHED → CLOSED | CANCELLED.
 * Transport programmé : PENDING → APPROVED | REJECTED | CANCELLED ; APPROVED → CLOSED | CANCELLED.
 * Une demande PENDING dont la date est passée est refusée automatiquement (REJECTED).
 */
public enum AmbulanceRequestStatus {
    PENDING,
    APPROVED,
    REJECTED,
    /** Envoi simulé : l'application n'est pas reliée à un centre de régulation (SAMU 190). */
    DISPATCHED,
    CLOSED,
    CANCELLED
}
