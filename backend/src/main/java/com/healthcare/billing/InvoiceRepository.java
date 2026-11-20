package com.healthcare.billing;

import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.List;
import java.util.Set;

public interface InvoiceRepository extends JpaRepository<Invoice, Long> {

    @EntityGraph(attributePaths = {"appointment", "ambulanceRequest", "patient", "doctor", "doctor.speciality", "company"})
    List<Invoice> findByPatientIdOrderByIdDesc(Long patientId);

    @EntityGraph(attributePaths = {"appointment", "ambulanceRequest", "patient", "doctor", "doctor.speciality", "company"})
    List<Invoice> findByDoctorIdOrderByIdDesc(Long doctorId);

    @Query("select i.appointment.id from Invoice i where i.appointment.id in :ids")
    Set<Long> findInvoicedAppointmentIds(@Param("ids") Collection<Long> appointmentIds);

    @EntityGraph(attributePaths = {"ambulanceRequest", "patient", "company"})
    List<Invoice> findByCompanyIdOrderByIdDesc(Long companyId);

    @Query("select i.ambulanceRequest.id from Invoice i where i.ambulanceRequest.id in :ids")
    Set<Long> findInvoicedAmbulanceRequestIds(@Param("ids") Collection<Long> ambulanceRequestIds);

    boolean existsByAppointmentId(Long appointmentId);

    boolean existsByAmbulanceRequestId(Long ambulanceRequestId);

    long countByNumberStartingWith(String prefix);
}
