package com.healthcare.doctor;

import com.healthcare.common.SearchPatterns;
import jakarta.persistence.LockModeType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;

public interface DoctorRepository extends JpaRepository<Doctor, Long> {

    @EntityGraph(attributePaths = {"speciality", "user"})
    Optional<Doctor> findByUserId(Long userId);

    @EntityGraph(attributePaths = {"speciality", "user"})
    Optional<Doctor> findWithDetailsById(Long id);

    /** Recherche des médecins actifs, par nom et/ou spécialité. */
    default Page<Doctor> search(String q, Long specialityId, Pageable pageable) {
        return searchByPattern(SearchPatterns.containsIgnoreCase(q), specialityId, pageable);
    }

    @EntityGraph(attributePaths = {"speciality"})
    @Query("""
            select d from Doctor d
            where d.user.enabled = true
              and (:specialityId is null or d.speciality.id = :specialityId)
              and (:pattern is null
                   or lower(d.firstName) like :pattern
                   or lower(d.lastName) like :pattern)
            """)
    Page<Doctor> searchByPattern(@Param("pattern") String pattern,
                                 @Param("specialityId") Long specialityId,
                                 Pageable pageable);

    /**
     * Verrou pessimiste sur la ligne du médecin pendant une prise de rendez-vous :
     * deux patients ne peuvent pas réserver le même créneau simultanément.
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select d from Doctor d where d.id = :id")
    Optional<Doctor> findByIdForUpdate(@Param("id") Long id);
}
