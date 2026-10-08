package com.healthcare.pharmacy.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.util.List;

/** Mise à jour en lot : point d'entrée pour une synchronisation depuis un logiciel de pharmacie externe. */
public record BulkStockRequest(
        @NotEmpty @Size(max = 1000) List<@Valid @NotNull StockRequest> items
) {
}
