package com.healthcare.stats.dto;

import com.healthcare.appointment.AppointmentStatus;
import com.healthcare.prescription.dto.MedicineUsage;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;

public record DoctorStatsResponse(
        long patientsFollowed,
        Map<AppointmentStatus, Long> appointmentsByStatus,
        long appointmentsToday,
        /** Rendez-vous en attente ou acceptés pour chacun des 7 prochains jours (aujourd'hui inclus). */
        List<DailyCount> upcomingPerDay,
        /** Part des demandes acceptées parmi celles traitées (acceptées + terminées + refusées), en % ; null si aucune. */
        Double acceptanceRate,
        long consultationsThisMonth,
        long prescriptionsIssued,
        long prescriptionsThisMonth,
        List<MedicineUsage> topMedicines,
        long pendingTransportValidations,
        long activeEmergencies
) {
    public record DailyCount(LocalDate date, long count) {
    }
}
