package com.healthcare.medicine;

import com.healthcare.common.BaseEntity;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/**
 * Référentiel central des médicaments (géré par l'admin).
 * Paracétamol 500 mg et 1000 mg sont deux références distinctes : unicité (nom, dosage, forme).
 */
@Entity
@Table(name = "medicines",
        uniqueConstraints = @UniqueConstraint(name = "uk_medicine_name_strength_form",
                columnNames = {"name", "strength", "form"}),
        indexes = @Index(name = "idx_medicine_name", columnList = "name"))
@Getter
@Setter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Medicine extends BaseEntity {

    @Column(nullable = false, length = 120)
    private String name;

    @Column(name = "active_ingredient", nullable = false, length = 120)
    private String activeIngredient;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private MedicineForm form;

    /** Dosage du produit (ex : "500 mg", "100 µg/dose"). */
    @Column(nullable = false, length = 40)
    private String strength;

    @Column(length = 120)
    private String manufacturer;

    public Medicine(String name, String activeIngredient, MedicineForm form, String strength, String manufacturer) {
        this.name = name;
        this.activeIngredient = activeIngredient;
        this.form = form;
        this.strength = strength;
        this.manufacturer = manufacturer;
    }
}
