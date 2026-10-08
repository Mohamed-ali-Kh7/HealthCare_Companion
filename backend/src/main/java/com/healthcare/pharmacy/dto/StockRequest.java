package com.healthcare.pharmacy.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;

/** Création ou mise à jour (upsert) de la ligne de stock d'un médicament. */
public record StockRequest(
        @NotNull Long medicineId,
        @NotNull @Min(0) @Max(1_000_000) Integer quantity,
        @DecimalMin("0.0") @Digits(integer = 7, fraction = 3) BigDecimal price
) {
}
