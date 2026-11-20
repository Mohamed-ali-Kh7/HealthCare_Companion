package com.healthcare.assistant;

import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface AssistantMessageRepository extends JpaRepository<AssistantMessage, Long> {

    /** Les plus récents d'abord (à inverser pour l'ordre chronologique). */
    List<AssistantMessage> findByPatientIdOrderByIdDesc(Long patientId, Pageable pageable);

    @Modifying
    @Query("delete from AssistantMessage m where m.patient.id = :patientId")
    int deleteByPatientId(@Param("patientId") Long patientId);
}
