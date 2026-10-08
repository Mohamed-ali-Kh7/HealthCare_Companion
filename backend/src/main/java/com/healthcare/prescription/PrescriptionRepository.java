package com.healthcare.prescription;

import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface PrescriptionRepository extends JpaRepository<Prescription, Long> {

    @EntityGraph(attributePaths = {"patient", "doctor", "doctor.speciality", "items", "items.medicine"})
    Optional<Prescription> findWithDetailsById(Long id);

    @EntityGraph(attributePaths = {"patient", "doctor", "doctor.speciality", "items", "items.medicine"})
    List<Prescription> findByPatientIdOrderByPrescriptionDateDescIdDesc(Long patientId);

    @EntityGraph(attributePaths = {"patient", "doctor", "doctor.speciality", "items", "items.medicine"})
    List<Prescription> findByDoctorIdOrderByPrescriptionDateDescIdDesc(Long doctorId);
}
