package com.healthcare.order.dto;

import com.healthcare.medicine.dto.MedicineResponse;
import com.healthcare.order.MedicineOrder;
import com.healthcare.order.OrderStatus;
import com.healthcare.order.OrderType;
import com.healthcare.patient.Patient;
import com.healthcare.pharmacy.dto.PharmacyResponse;

import java.math.BigDecimal;
import java.time.Instant;

public record OrderResponse(
        Long id,
        OrderType type,
        OrderStatus status,
        int quantity,
        BigDecimal unitPrice,
        BigDecimal totalPrice,
        String deliveryAddress,
        String phone,
        String note,
        String pharmacistNote,
        Instant createdAt,
        Instant updatedAt,
        MedicineResponse medicine,
        PharmacyResponse pharmacy,
        PatientInfo patient
) {
    /** Ce dont la pharmacie a besoin pour préparer et remettre la commande. */
    public record PatientInfo(Long id, String firstName, String lastName, String phone) {
    }

    public static OrderResponse from(MedicineOrder o) {
        Patient p = o.getPatient();
        return new OrderResponse(o.getId(), o.getType(), o.getStatus(), o.getQuantity(), o.getUnitPrice(),
                o.getTotalPrice(), o.getDeliveryAddress(), o.getPhone(), o.getNote(), o.getPharmacistNote(),
                o.getCreatedAt(), o.getUpdatedAt(), MedicineResponse.from(o.getMedicine()),
                PharmacyResponse.from(o.getPharmacy()),
                new PatientInfo(p.getId(), p.getFirstName(), p.getLastName(), p.getPhone()));
    }
}
