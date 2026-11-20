package com.healthcare.transport;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.List;

public interface AmbulanceVehicleRepository extends JpaRepository<AmbulanceVehicle, Long> {

    List<AmbulanceVehicle> findByCompanyIdOrderByPlateAsc(Long companyId);

    boolean existsByPlateIgnoreCase(String plate);

    /** [companyId, nombre de véhicules en service] */
    @Query("""
            select v.company.id, count(v) from AmbulanceVehicle v
            where v.company.id in :companyIds and v.inService = true group by v.company.id
            """)
    List<Object[]> countInServiceByCompany(@Param("companyIds") Collection<Long> companyIds);
}
