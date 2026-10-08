package com.healthcare.pharmacy;

import com.healthcare.common.BaseEntity;
import com.healthcare.medicine.Medicine;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;

/**
 * Ligne d'inventaire : une seule ligne par (pharmacie, médicament) — une mise à jour
 * modifie la ligne existante au lieu d'en insérer une nouvelle.
 * La date de dernière mise à jour est updatedAt (BaseEntity).
 */
@Entity
@Table(name = "stocks",
        uniqueConstraints = @UniqueConstraint(name = "uk_stock_pharmacy_medicine",
                columnNames = {"pharmacy_id", "medicine_id"}),
        indexes = @Index(name = "idx_stock_medicine", columnList = "medicine_id"))
@Getter
@Setter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Stock extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "pharmacy_id", nullable = false)
    private Pharmacy pharmacy;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "medicine_id", nullable = false)
    private Medicine medicine;

    @Column(nullable = false)
    private int quantity;

    /** BigDecimal (jamais double pour de l'argent). 3 décimales : le dinar tunisien compte des millimes. */
    @Column(precision = 10, scale = 3)
    private BigDecimal price;

    public Stock(Pharmacy pharmacy, Medicine medicine, int quantity, BigDecimal price) {
        this.pharmacy = pharmacy;
        this.medicine = medicine;
        this.quantity = quantity;
        this.price = price;
    }
}
