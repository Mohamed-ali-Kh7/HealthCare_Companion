package com.healthcare.telemonitoring;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.Collection;
import java.util.List;

public interface SensorDataRepository extends JpaRepository<SensorData, Long> {

    List<SensorData> findTop5000ByPatientIdAndSensorTypeAndRecordedAtBetweenOrderByRecordedAtAsc(
            Long patientId, SensorType sensorType, Instant from, Instant to);

    /** Horodatages déjà enregistrés parmi ceux d'un lot (détection des doublons). */
    @Query("""
            select s.recordedAt from SensorData s
            where s.patient.id = :patientId and s.sensorType = :type and s.recordedAt in :instants
            """)
    List<Instant> findExistingInstants(@Param("patientId") Long patientId,
                                       @Param("type") SensorType type,
                                       @Param("instants") Collection<Instant> instants);

    long countByCreatedAtAfter(Instant since);
}
