package com.healthcare.transport;

import com.healthcare.common.BaseEntity;
import com.healthcare.user.User;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/**
 * Société d'ambulance conventionnée CNAM, rattachée au compte de son gérant (1-1).
 * Réalise les transports sanitaires programmés validés par un médecin. Le compte est validé par l'administrateur.
 */
@Entity
@Table(name = "ambulance_companies",
        uniqueConstraints = @UniqueConstraint(name = "uk_ambulance_companies_user", columnNames = "user_id"))
@Getter
@Setter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class AmbulanceCompany extends BaseEntity {

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(nullable = false, length = 120)
    private String name;

    /** Numéro de convention avec la CNAM. */
    @Column(name = "convention_number", nullable = false, length = 30)
    private String conventionNumber;

    @Column(nullable = false, length = 255)
    private String address;

    @Column(nullable = false, length = 80)
    private String city;

    @Column(nullable = false, length = 30)
    private String phone;

    @Column(nullable = false)
    private double latitude;

    @Column(nullable = false)
    private double longitude;

    /** Rayon d'intervention en km. */
    @Column(name = "service_radius_km", nullable = false)
    private int serviceRadiusKm = 30;

    /** Accepte de nouvelles demandes (désactivable temporairement par la société). */
    @Column(name = "accepting_requests", nullable = false)
    private boolean acceptingRequests = true;

    public AmbulanceCompany(User user, String name, String conventionNumber, String address, String city, String phone,
                            double latitude, double longitude) {
        this.user = user;
        this.name = name;
        this.conventionNumber = conventionNumber;
        this.address = address;
        this.city = city;
        this.phone = phone;
        this.latitude = latitude;
        this.longitude = longitude;
    }
}
