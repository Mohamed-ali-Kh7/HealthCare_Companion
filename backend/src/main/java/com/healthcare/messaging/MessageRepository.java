package com.healthcare.messaging;

import com.healthcare.user.Role;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;

public interface MessageRepository extends JpaRepository<Message, Long> {

    /** Messages d'une conversation, du plus récent au plus ancien (pagination par curseur sur l'id). */
    @Query("""
            select m from Message m
            where m.patient.id = :patientId and m.doctor.id = :doctorId
              and (:beforeId is null or m.id < :beforeId)
            order by m.id desc
            """)
    List<Message> findPage(@Param("patientId") Long patientId,
                           @Param("doctorId") Long doctorId,
                           @Param("beforeId") Long beforeId,
                           Pageable pageable);

    /** Nouveaux messages depuis le dernier connu (rafraîchissement périodique du client). */
    @Query("""
            select m from Message m
            where m.patient.id = :patientId and m.doctor.id = :doctorId and m.id > :afterId
            order by m.id asc
            """)
    List<Message> findAfter(@Param("patientId") Long patientId,
                            @Param("doctorId") Long doctorId,
                            @Param("afterId") Long afterId,
                            Pageable pageable);

    /** Dernier message de chaque conversation d'un patient. */
    @Query("""
            select m from Message m where m.id in (
                select max(m2.id) from Message m2 where m2.patient.id = :patientId group by m2.doctor.id)
            """)
    List<Message> findLastMessagesOfPatient(@Param("patientId") Long patientId);

    /** Dernier message de chaque conversation d'un médecin. */
    @Query("""
            select m from Message m where m.id in (
                select max(m2.id) from Message m2 where m2.doctor.id = :doctorId group by m2.patient.id)
            """)
    List<Message> findLastMessagesOfDoctor(@Param("doctorId") Long doctorId);

    /** Non lus reçus par un patient, par médecin : lignes [doctorId, count]. */
    @Query("""
            select m.doctor.id, count(m) from Message m
            where m.patient.id = :patientId and m.senderRole = :senderRole and m.readAt is null
            group by m.doctor.id
            """)
    List<Object[]> countUnreadForPatient(@Param("patientId") Long patientId, @Param("senderRole") Role senderRole);

    /** Non lus reçus par un médecin, par patient : lignes [patientId, count]. */
    @Query("""
            select m.patient.id, count(m) from Message m
            where m.doctor.id = :doctorId and m.senderRole = :senderRole and m.readAt is null
            group by m.patient.id
            """)
    List<Object[]> countUnreadForDoctor(@Param("doctorId") Long doctorId, @Param("senderRole") Role senderRole);

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("""
            update Message m set m.readAt = :now
            where m.patient.id = :patientId and m.doctor.id = :doctorId
              and m.senderRole = :senderRole and m.readAt is null
            """)
    int markAsRead(@Param("patientId") Long patientId,
                   @Param("doctorId") Long doctorId,
                   @Param("senderRole") Role senderRole,
                   @Param("now") Instant now);
}
