package com.healthcare.transport;

import com.healthcare.common.BaseEntity;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/** Véhicule de la flotte d'une société, avec son équipage habituel. */
@Entity
@Table(name = "ambulance_vehicles",
        uniqueConstraints = @UniqueConstraint(name = "uk_ambulance_vehicles_plate", columnNames = "plate"),
        indexes = @Index(name = "idx_ambulance_vehicles_company", columnList = "company_id"))
@Getter
@Setter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class AmbulanceVehicle extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "company_id", nullable = false)
    private AmbulanceCompany company;

    /** Immatriculation (ex : 123 TU 4567). */
    @Column(nullable = false, length = 20)
    private String plate;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private VehicleType type;

    @Column(name = "driver_name", length = 80)
    private String driverName;

    @Column(name = "driver_phone", length = 30)
    private String driverPhone;

    /** En service (faux : en panne, en entretien...). */
    @Column(name = "in_service", nullable = false)
    private boolean inService = true;

    public AmbulanceVehicle(AmbulanceCompany company, String plate, VehicleType type, String driverName,
                            String driverPhone) {
        this.company = company;
        this.plate = plate;
        this.type = type;
        this.driverName = driverName;
        this.driverPhone = driverPhone;
    }
}
