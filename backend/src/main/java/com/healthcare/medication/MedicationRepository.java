package com.healthcare.medication;

import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface MedicationRepository extends JpaRepository<Medication, Long> {

    @EntityGraph(attributePaths = {"medicine", "reminderTimes"})
    List<Medication> findByPatientIdOrderByStartDateDesc(Long patientId);

    @EntityGraph(attributePaths = {"medicine", "reminderTimes", "patient"})
    Optional<Medication> findWithDetailsById(Long id);

    /** Traitements actifs et en cours à la date donnée. */
    @Query("""
            select count(m) from Medication m
            where m.patient.id = :patientId and m.active = true
              and m.startDate <= :day and (m.endDate is null or m.endDate >= :day)
            """)
    long countOngoing(@Param("patientId") Long patientId, @Param("day") LocalDate day);
}
