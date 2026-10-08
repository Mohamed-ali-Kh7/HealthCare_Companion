package com.healthcare.prescription.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.util.List;

public record CreatePrescriptionRequest(
        @NotNull Long patientId,
        @Size(max = 1000) String notes,
        @NotEmpty @Size(max = 20) List<@Valid @NotNull PrescriptionItemRequest> items
) {
}
