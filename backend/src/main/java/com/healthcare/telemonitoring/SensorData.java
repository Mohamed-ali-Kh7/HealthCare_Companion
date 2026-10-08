package com.healthcare.telemonitoring;

import com.healthcare.common.BaseEntity;
import com.healthcare.patient.Patient;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.Instant;

/**
 * Mesure horodatée d'un capteur du patient.
 * Unicité (patient, type, recordedAt) : un renvoi après coupure réseau ne crée pas de doublon.
 * recordedAt = moment de la mesure sur le téléphone ; createdAt (BaseEntity) = réception serveur.
 */
@Entity
@Table(name = "sensor_data",
        uniqueConstraints = @UniqueConstraint(name = "uk_sensor_reading",
                columnNames = {"patient_id", "sensor_type", "recorded_at"}),
        indexes = @Index(name = "idx_sensor_patient_type_time",
                columnList = "patient_id, sensor_type, recorded_at"))
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class SensorData extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "patient_id", nullable = false)
    private Patient patient;

    @Enumerated(EnumType.STRING)
    @Column(name = "sensor_type", nullable = false, length = 20)
    private SensorType sensorType;

    @Column(name = "measured_value", nullable = false)
    private double value;

    @Column(name = "recorded_at", nullable = false)
    private Instant recordedAt;

    public SensorData(Patient patient, SensorType sensorType, double value, Instant recordedAt) {
        this.patient = patient;
        this.sensorType = sensorType;
        this.value = value;
        this.recordedAt = recordedAt;
    }
}
