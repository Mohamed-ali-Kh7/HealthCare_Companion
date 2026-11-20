package com.healthcare.order;

import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface MedicineOrderRepository extends JpaRepository<MedicineOrder, Long> {

    @EntityGraph(attributePaths = {"patient", "pharmacy", "medicine"})
    List<MedicineOrder> findByPatientIdOrderByCreatedAtDesc(Long patientId);

    @EntityGraph(attributePaths = {"patient", "pharmacy", "medicine"})
    List<MedicineOrder> findByPharmacyIdOrderByCreatedAtDesc(Long pharmacyId);

    @EntityGraph(attributePaths = {"patient", "pharmacy", "medicine"})
    Optional<MedicineOrder> findWithDetailsById(Long id);

    long countByPatientIdAndStatusIn(Long patientId, List<OrderStatus> statuses);
}
