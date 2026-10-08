package com.healthcare.pharmacy;

import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface StockRepository extends JpaRepository<Stock, Long> {

    @EntityGraph(attributePaths = "medicine")
    List<Stock> findByPharmacyIdOrderByMedicineNameAsc(Long pharmacyId);

    @EntityGraph(attributePaths = {"medicine", "pharmacy"})
    Optional<Stock> findWithDetailsById(Long id);

    Optional<Stock> findByPharmacyIdAndMedicineId(Long pharmacyId, Long medicineId);

    /**
     * Même logique que PharmacyRepository.findNearby, restreinte aux pharmacies ayant le médicament en stock.
     * Retour : lignes [pharmacyId, distanceKm, quantity, price].
     */
    @Query(value = """
            SELECT t.pharmacyId AS pharmacyId, t.distance AS distance,
                   t.quantity AS quantity, t.price AS price
            FROM (
                SELECT p.id AS pharmacyId, s.quantity AS quantity, s.price AS price,
                       6371 * ACOS(LEAST(1.0,
                           COS(RADIANS(:lat)) * COS(RADIANS(p.latitude)) * COS(RADIANS(p.longitude) - RADIANS(:lng))
                           + SIN(RADIANS(:lat)) * SIN(RADIANS(p.latitude)))) AS distance
                FROM stocks s
                JOIN pharmacies p ON p.id = s.pharmacy_id
                JOIN users u ON u.id = p.user_id
                WHERE s.medicine_id = :medicineId
                  AND s.quantity > 0
                  AND u.enabled = TRUE
                  AND p.latitude BETWEEN :minLat AND :maxLat
                  AND p.longitude BETWEEN :minLng AND :maxLng
            ) t
            WHERE t.distance <= :radiusKm
            ORDER BY t.distance
            LIMIT :maxResults
            """, nativeQuery = true)
    List<Object[]> findAvailabilityNearby(@Param("medicineId") Long medicineId,
                                                   @Param("lat") double lat,
                                                   @Param("lng") double lng,
                                                   @Param("minLat") double minLat,
                                                   @Param("maxLat") double maxLat,
                                                   @Param("minLng") double minLng,
                                                   @Param("maxLng") double maxLng,
                                                   @Param("radiusKm") double radiusKm,
                                                   @Param("maxResults") int maxResults);
}
