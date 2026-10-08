package com.healthcare.medicine.dto;

import com.healthcare.medicine.MedicineForm;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record MedicineRequest(
        @NotBlank @Size(max = 120) String name,
        @NotBlank @Size(max = 120) String activeIngredient,
        @NotNull MedicineForm form,
        @NotBlank @Size(max = 40) String strength,
        @Size(max = 120) String manufacturer
) {
}
