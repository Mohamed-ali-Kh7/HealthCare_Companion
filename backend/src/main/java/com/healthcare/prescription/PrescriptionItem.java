package com.healthcare.prescription;

import com.healthcare.common.BaseEntity;
import com.healthcare.medicine.Medicine;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

/** Ligne d'ordonnance. timesPerDay (structuré) permet de générer les rappels du carnet patient. */
@Entity
@Table(name = "prescription_items")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class PrescriptionItem extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "prescription_id", nullable = false)
    private Prescription prescription;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "medicine_id", nullable = false)
    private Medicine medicine;

    /** Posologie unitaire (ex : "1 comprimé"). */
    @Column(name = "prescribed_dosage", nullable = false, length = 60)
    private String prescribedDosage;

    @Column(name = "times_per_day", nullable = false)
    private int timesPerDay;

    @Column(name = "duration_days", nullable = false)
    private int durationDays;

    /** Nuances humaines (ex : "au milieu du repas"). */
    @Column(length = 500)
    private String instructions;

    public PrescriptionItem(Medicine medicine, String prescribedDosage, int timesPerDay,
                            int durationDays, String instructions) {
        this.medicine = medicine;
        this.prescribedDosage = prescribedDosage;
        this.timesPerDay = timesPerDay;
        this.durationDays = durationDays;
        this.instructions = instructions;
    }

    void attachTo(Prescription prescription) {
        this.prescription = prescription;
    }
}
