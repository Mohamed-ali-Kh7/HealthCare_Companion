package com.healthcare.pharmacy;

import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface PharmacyRepository extends JpaRepository<Pharmacy, Long> {

    Optional<Pharmacy> findByUserId(Long userId);

    @EntityGraph(attributePaths = "user")
    List<Pharmacy> findByIdIn(List<Long> ids);

    /**
     * Pharmacies actives dans un rayon (km), triées par distance.
     * 1) pré-filtre rectangulaire (bounding box) qui exploite l'index (latitude, longitude) ;
     * 2) distance exacte par la formule de Haversine (rayon terrestre 6371 km).
     * LEAST(1.0, ...) protège ACOS contre les erreurs d'arrondi (> 1).
     * Retour : lignes [id, distanceKm] (Object[] : indépendant de la casse des alias selon le SGBD).
     */
    @Query(value = """
            SELECT t.id AS id, t.distance AS distance FROM (
                SELECT p.id AS id,
                       6371 * ACOS(LEAST(1.0,
                           COS(RADIANS(:lat)) * COS(RADIANS(p.latitude)) * COS(RADIANS(p.longitude) - RADIANS(:lng))
                           + SIN(RADIANS(:lat)) * SIN(RADIANS(p.latitude)))) AS distance
                FROM pharmacies p
                JOIN users u ON u.id = p.user_id
                WHERE u.enabled = TRUE
                  AND p.latitude BETWEEN :minLat AND :maxLat
                  AND p.longitude BETWEEN :minLng AND :maxLng
            ) t
            WHERE t.distance <= :radiusKm
            ORDER BY t.distance
            LIMIT :maxResults
            """, nativeQuery = true)
    List<Object[]> findNearby(@Param("lat") double lat,
                                      @Param("lng") double lng,
                                      @Param("minLat") double minLat,
                                      @Param("maxLat") double maxLat,
                                      @Param("minLng") double minLng,
                                      @Param("maxLng") double maxLng,
                                      @Param("radiusKm") double radiusKm,
                                      @Param("maxResults") int maxResults);
}
