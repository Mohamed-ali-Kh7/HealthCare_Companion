package com.healthcare.pharmacy.dto;

import java.math.BigDecimal;

/** Une pharmacie proche qui a le médicament recherché en stock. */
public record MedicineAvailabilityResponse(PharmacyResponse pharmacy, int quantity, BigDecimal price) {
}
