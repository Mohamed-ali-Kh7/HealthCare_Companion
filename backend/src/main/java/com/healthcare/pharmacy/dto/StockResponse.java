package com.healthcare.pharmacy.dto;

import com.healthcare.medicine.dto.MedicineResponse;
import com.healthcare.pharmacy.Stock;

import java.math.BigDecimal;
import java.time.Instant;

public record StockResponse(
        Long id,
        MedicineResponse medicine,
        int quantity,
        BigDecimal price,
        Instant lastUpdated
) {
    public static StockResponse from(Stock s) {
        return new StockResponse(s.getId(), MedicineResponse.from(s.getMedicine()),
                s.getQuantity(), s.getPrice(), s.getUpdatedAt());
    }
}
