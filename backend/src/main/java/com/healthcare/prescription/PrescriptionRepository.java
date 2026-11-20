package com.healthcare.prescription;

import com.healthcare.prescription.dto.MedicineUsage;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface PrescriptionRepository extends JpaRepository<Prescription, Long> {

    @EntityGraph(attributePaths = {"patient", "doctor", "doctor.speciality", "items", "items.medicine"})
    Optional<Prescription> findWithDetailsById(Long id);

    @EntityGraph(attributePaths = {"patient", "doctor", "doctor.speciality", "items", "items.medicine"})
    List<Prescription> findByPatientIdOrderByPrescriptionDateDescIdDesc(Long patientId);

    @EntityGraph(attributePaths = {"patient", "doctor", "doctor.speciality", "items", "items.medicine"})
    List<Prescription> findByDoctorIdOrderByPrescriptionDateDescIdDesc(Long doctorId);

    // ---------------------------------------------------------------- Statistiques

    long countByPatientId(Long patientId);

    long countByDoctorId(Long doctorId);

    long countByDoctorIdAndPrescriptionDateGreaterThanEqual(Long doctorId, LocalDate from);

    /** Médicaments les plus prescrits par un médecin (une ligne d'ordonnance = une prescription). */
    @Query("""
            select new com.healthcare.prescription.dto.MedicineUsage(m.id, m.name, m.strength, count(i))
            from PrescriptionItem i join i.medicine m
            where i.prescription.doctor.id = :doctorId
            group by m.id, m.name, m.strength
            order by count(i) desc, m.name asc
            """)
    List<MedicineUsage> findTopMedicinesOfDoctor(@Param("doctorId") Long doctorId, Pageable pageable);
}
