package com.healthcare.transport;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface AmbulanceCompanyRepository extends JpaRepository<AmbulanceCompany, Long> {

    Optional<AmbulanceCompany> findByUserId(Long userId);

    /** Sociétés dont le compte est validé et qui acceptent des demandes, dans un rectangle (pré-filtre). */
    @Query("""
            select c from AmbulanceCompany c
            where c.user.enabled = true and c.acceptingRequests = true
              and c.latitude between :minLat and :maxLat and c.longitude between :minLng and :maxLng
            """)
    List<AmbulanceCompany> findActiveInBox(@Param("minLat") double minLat, @Param("maxLat") double maxLat,
                                           @Param("minLng") double minLng, @Param("maxLng") double maxLng);
}
