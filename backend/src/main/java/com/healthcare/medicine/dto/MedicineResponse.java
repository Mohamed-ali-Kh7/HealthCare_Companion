package com.healthcare.medicine.dto;

import com.healthcare.medicine.Medicine;
import com.healthcare.medicine.MedicineForm;

public record MedicineResponse(
        Long id,
        String name,
        String activeIngredient,
        MedicineForm form,
        String strength,
        String manufacturer
) {
    public static MedicineResponse from(Medicine m) {
        return new MedicineResponse(m.getId(), m.getName(), m.getActiveIngredient(), m.getForm(),
                m.getStrength(), m.getManufacturer());
    }
}
