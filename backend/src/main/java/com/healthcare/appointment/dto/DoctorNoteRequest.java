package com.healthcare.appointment.dto;

import jakarta.validation.constraints.Size;

/** Motif de refus ou compte rendu court (optionnel). */
public record DoctorNoteRequest(@Size(max = 500) String note) {
}
