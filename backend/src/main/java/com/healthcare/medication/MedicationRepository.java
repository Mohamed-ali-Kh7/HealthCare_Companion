package com.healthcare.medication;

import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface MedicationRepository extends JpaRepository<Medication, Long> {

    @EntityGraph(attributePaths = {"medicine", "reminderTimes"})
    List<Medication> findByPatientIdOrderByStartDateDesc(Long patientId);

    @EntityGraph(attributePaths = {"medicine", "reminderTimes", "patient"})
    Optional<Medication> findWithDetailsById(Long id);
}
