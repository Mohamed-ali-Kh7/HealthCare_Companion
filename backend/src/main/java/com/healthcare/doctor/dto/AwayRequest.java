package com.healthcare.doctor.dto;

import jakarta.validation.constraints.Size;

import java.time.LocalDate;

/**
 * {"away":true,"message":"En congé, de retour lundi","until":"2026-11-20"}
 * {"away":false} : de nouveau disponible.
 */
public record AwayRequest(boolean away, @Size(max = 300) String message, LocalDate until) {
}
