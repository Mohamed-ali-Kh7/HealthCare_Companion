package com.healthcare.order;

import com.healthcare.common.BaseEntity;
import com.healthcare.common.exception.BusinessRuleException;
import com.healthcare.medicine.Medicine;
import com.healthcare.patient.Patient;
import com.healthcare.pharmacy.Pharmacy;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

/**
 * Réservation ou commande en ligne d'un médicament auprès d'une pharmacie.
 * Les transitions de statut sont encapsulées ici (voir {@link OrderStatus}).
 * Le prix est figé à la création : un changement de tarif ultérieur ne modifie pas la commande.
 */
@Entity
@Table(name = "medicine_orders", indexes = {
        @Index(name = "idx_order_patient", columnList = "patient_id"),
        @Index(name = "idx_order_pharmacy_status", columnList = "pharmacy_id, status")
})
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class MedicineOrder extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "patient_id", nullable = false)
    private Patient patient;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "pharmacy_id", nullable = false)
    private Pharmacy pharmacy;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "medicine_id", nullable = false)
    private Medicine medicine;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private OrderType type;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private OrderStatus status = OrderStatus.PENDING;

    @Column(nullable = false)
    private int quantity;

    /** Prix unitaire au moment de la commande (null : prix non communiqué par la pharmacie). */
    @Column(name = "unit_price", precision = 10, scale = 3)
    private BigDecimal unitPrice;

    @Column(name = "delivery_address", length = 255)
    private String deliveryAddress;

    @Column(length = 30)
    private String phone;

    @Column(length = 500)
    private String note;

    /** Motif de refus ou message de la pharmacie (ex : « à retirer avant 19 h »). */
    @Column(name = "pharmacist_note", length = 500)
    private String pharmacistNote;

    public MedicineOrder(Patient patient, Pharmacy pharmacy, Medicine medicine, OrderType type, int quantity,
                         BigDecimal unitPrice, String deliveryAddress, String phone, String note) {
        this.patient = patient;
        this.pharmacy = pharmacy;
        this.medicine = medicine;
        this.type = type;
        this.quantity = quantity;
        this.unitPrice = unitPrice;
        this.deliveryAddress = deliveryAddress;
        this.phone = phone;
        this.note = note;
    }

    public BigDecimal getTotalPrice() {
        return unitPrice == null ? null : unitPrice.multiply(BigDecimal.valueOf(quantity));
    }

    public void confirm(String note) {
        requireStatus(OrderStatus.PENDING);
        status = OrderStatus.CONFIRMED;
        pharmacistNote = note;
    }

    public void reject(String note) {
        requireStatus(OrderStatus.PENDING);
        status = OrderStatus.REJECTED;
        pharmacistNote = note;
    }

    public void complete() {
        requireStatus(OrderStatus.CONFIRMED);
        status = OrderStatus.COMPLETED;
    }

    /** Annulation par le patient, tant que le médicament n'est pas retiré / livré. */
    public void cancel() {
        if (status != OrderStatus.PENDING && status != OrderStatus.CONFIRMED) {
            throw new BusinessRuleException("INVALID_STATUS_TRANSITION",
                    "Cette commande ne peut plus être annulée (" + status + ")");
        }
        status = OrderStatus.CANCELLED;
    }

    private void requireStatus(OrderStatus expected) {
        if (status != expected) {
            throw new BusinessRuleException("INVALID_STATUS_TRANSITION",
                    "Opération impossible : la commande est " + status);
        }
    }
}
