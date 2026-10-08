package com.healthcare.pharmacy;

import com.healthcare.common.BaseEntity;
import com.healthcare.user.User;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/**
 * Officine rattachée au compte de son pharmacien (1-1).
 * Coordonnées GPS en DOUBLE : recherche de proximité par formule de Haversine.
 */
@Entity
@Table(name = "pharmacies",
        uniqueConstraints = @UniqueConstraint(name = "uk_pharmacies_user", columnNames = "user_id"),
        indexes = @Index(name = "idx_pharmacy_lat_lng", columnList = "latitude, longitude"))
@Getter
@Setter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Pharmacy extends BaseEntity {

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(nullable = false, length = 120)
    private String name;

    @Column(nullable = false, length = 255)
    private String address;

    @Column(length = 30)
    private String phone;

    @Column(nullable = false)
    private double latitude;

    @Column(nullable = false)
    private double longitude;

    /** Texte libre (ex : "Lun-Sam 08:00-20:00"). */
    @Column(name = "opening_hours", length = 120)
    private String openingHours;

    /** Pharmacie de garde (ouverte la nuit / le week-end). */
    @Column(name = "on_duty", nullable = false)
    private boolean onDuty = false;

    public Pharmacy(User user, String name, String address, String phone, double latitude, double longitude) {
        this.user = user;
        this.name = name;
        this.address = address;
        this.phone = phone;
        this.latitude = latitude;
        this.longitude = longitude;
    }
}
