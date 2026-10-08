package com.healthcare.patient;

import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface PatientRepository extends JpaRepository<Patient, Long> {

    @EntityGraph(attributePaths = "user")
    Optional<Patient> findByUserId(Long userId);

    @EntityGraph(attributePaths = "user")
    Optional<Patient> findWithUserById(Long id);

    @EntityGraph(attributePaths = "user")
    List<Patient> findByIdIn(Collection<Long> ids);
}
