package com.healthcare.appointment.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.LocalDateTime;

/** Exemple : {"doctorId":3,"appointmentDate":"2026-10-12T09:30:00","reason":"Contrôle annuel"} */
public record CreateAppointmentRequest(
        @NotNull Long doctorId,
        @NotNull LocalDateTime appointmentDate, // futur + créneau libre vérifiés par le service (fuseau métier)
        @Size(max = 500) String reason
) {
}
