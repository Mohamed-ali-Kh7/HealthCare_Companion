package com.healthcare.journal;

import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface SymptomEntryRepository extends JpaRepository<SymptomEntry, Long> {

    Optional<SymptomEntry> findByPatientIdAndEntryDate(Long patientId, LocalDate entryDate);

    List<SymptomEntry> findByPatientIdAndEntryDateBetweenOrderByEntryDateAsc(Long patientId, LocalDate from, LocalDate to);
}
