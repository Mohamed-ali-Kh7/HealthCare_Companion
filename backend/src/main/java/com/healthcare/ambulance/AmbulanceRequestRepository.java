package com.healthcare.ambulance;

import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;
import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface AmbulanceRequestRepository extends JpaRepository<AmbulanceRequest, Long> {

    @EntityGraph(attributePaths = {"patient", "doctor", "company", "vehicle"})
    Optional<AmbulanceRequest> findWithDetailsById(Long id);

    @EntityGraph(attributePaths = {"patient", "doctor", "company", "vehicle"})
    List<AmbulanceRequest> findByPatientIdOrderByCreatedAtDesc(Long patientId);

    /**
     * Vue médecin : les urgences de ses patients (même non prises en charge)
     * et les demandes qui lui sont adressées ou qu'il a prises en charge.
     */
    @EntityGraph(attributePaths = {"patient", "doctor", "company", "vehicle"})
    @Query("""
            select r from AmbulanceRequest r left join r.doctor d
            where (r.type = com.healthcare.ambulance.AmbulanceRequestType.EMERGENCY and r.patient.id in :patientIds)
               or d.id = :doctorId
            order by r.createdAt desc
            """)
    List<AmbulanceRequest> findForDoctor(@Param("doctorId") Long doctorId,
                                         @Param("patientIds") Collection<Long> patientIds);

    /** Missions confiées à une société, les plus proches dans le temps d'abord. */
    @EntityGraph(attributePaths = {"patient", "doctor", "company", "vehicle"})
    List<AmbulanceRequest> findByCompanyIdOrderByScheduledAtAsc(Long companyId);

    boolean existsByPatientIdAndTypeAndStatus(Long patientId, AmbulanceRequestType type,
                                              AmbulanceRequestStatus status);

    List<AmbulanceRequest> findByStatusAndScheduledAtBefore(AmbulanceRequestStatus status, LocalDateTime before);

    // ---------------------------------------------------------------- Statistiques

    long countByPatientId(Long patientId);

    long countByDoctorIdAndStatus(Long doctorId, AmbulanceRequestStatus status);

    long countByTypeAndStatusAndPatientIdIn(AmbulanceRequestType type, AmbulanceRequestStatus status,
                                            Collection<Long> patientIds);
}
