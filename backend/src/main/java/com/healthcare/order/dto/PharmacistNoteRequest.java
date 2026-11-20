package com.healthcare.order.dto;

import jakarta.validation.constraints.Size;

/** Message optionnel de la pharmacie (motif de refus, consigne de retrait...). */
public record PharmacistNoteRequest(@Size(max = 500) String note) {
}
