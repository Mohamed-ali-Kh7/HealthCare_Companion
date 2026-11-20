package com.healthcare.ambulance.dto;

import com.healthcare.ambulance.AmbulanceRequestType;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.LocalDateTime;

/**
 * Urgence : {"type":"EMERGENCY","latitude":36.80,"longitude":10.18,"reason":"Douleur thoracique"}
 * Transport : {"type":"SCHEDULED","doctorId":1,"address":"...","scheduledAt":"2026-11-20T08:00:00"}
 * Champs obligatoires selon le type : vérifiés par le service.
 */
public record CreateAmbulanceRequest(
        @NotNull AmbulanceRequestType type,
        @DecimalMin("-90") @DecimalMax("90") Double latitude,
        @DecimalMin("-180") @DecimalMax("180") Double longitude,
        @Size(max = 255) String address,
        @Size(max = 500) String reason,
        Long doctorId,
        LocalDateTime scheduledAt
) {
}
