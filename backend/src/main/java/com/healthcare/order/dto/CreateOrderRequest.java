package com.healthcare.order.dto;

import com.healthcare.order.OrderType;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/**
 * Réservation : {"type":"RESERVATION","pharmacyId":1,"medicineId":3,"quantity":2}
 * Commande    : {"type":"DELIVERY","pharmacyId":1,"medicineId":3,"quantity":1,
 *                "deliveryAddress":"12 rue de Marseille, Tunis","phone":"+216 20 000 001"}
 */
public record CreateOrderRequest(
        @NotNull OrderType type,
        @NotNull Long pharmacyId,
        @NotNull Long medicineId,
        @Min(1) @Max(10) int quantity,
        @Size(max = 255) String deliveryAddress,
        @Size(max = 30) String phone,
        @Size(max = 500) String note
) {
}
