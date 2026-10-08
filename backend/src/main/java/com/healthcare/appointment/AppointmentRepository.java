package com.healthcare.appointment;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;
import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface AppointmentRepository extends JpaRepository<Appointment, Long> {

    @EntityGraph(attributePaths = {"patient", "doctor", "doctor.speciality"})
    Optional<Appointment> findWithDetailsById(Long id);

    @EntityGraph(attributePaths = {"patient", "doctor", "doctor.speciality"})
    List<Appointment> findByPatientIdOrderByAppointmentDateDesc(Long patientId);

    @EntityGraph(attributePaths = {"patient", "doctor", "doctor.speciality"})
    @Query("""
            select a from Appointment a
            where a.doctor.id = :doctorId
              and (:status is null or a.status = :status)
              and (:from is null or a.appointmentDate >= :from)
              and (:to is null or a.appointmentDate < :to)
            order by a.appointmentDate asc
            """)
    List<Appointment> findForDoctor(@Param("doctorId") Long doctorId,
                                    @Param("status") AppointmentStatus status,
                                    @Param("from") LocalDateTime from,
                                    @Param("to") LocalDateTime to);

    @EntityGraph(attributePaths = {"patient", "doctor", "doctor.speciality"})
    @Query("select a from Appointment a where (:status is null or a.status = :status)")
    Page<Appointment> findAllByStatus(@Param("status") AppointmentStatus status, Pageable pageable);

    /** Dates déjà occupées pour un médecin sur une plage (génération des créneaux libres). */
    @Query("""
            select a.appointmentDate from Appointment a
            where a.doctor.id = :doctorId
              and a.status in :statuses
              and a.appointmentDate >= :from and a.appointmentDate < :to
            """)
    List<LocalDateTime> findBookedDates(@Param("doctorId") Long doctorId,
                                        @Param("statuses") Collection<AppointmentStatus> statuses,
                                        @Param("from") LocalDateTime from,
                                        @Param("to") LocalDateTime to);

    boolean existsByDoctorIdAndPatientIdAndStatusIn(Long doctorId, Long patientId,
                                                     Collection<AppointmentStatus> statuses);

    @Query("""
            select distinct a.patient.id from Appointment a
            where a.doctor.id = :doctorId and a.status in :statuses
            """)
    List<Long> findPatientIdsOfDoctor(@Param("doctorId") Long doctorId,
                                      @Param("statuses") Collection<AppointmentStatus> statuses);

    long countByStatus(AppointmentStatus status);
}
