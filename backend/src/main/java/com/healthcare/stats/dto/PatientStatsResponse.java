package com.healthcare.stats.dto;

import com.healthcare.appointment.AppointmentStatus;
import com.healthcare.appointment.dto.AppointmentResponse;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;

public record PatientStatsResponse(
        Map<AppointmentStatus, Long> appointmentsByStatus,
        /** null s'il n'y a aucun rendez-vous à venir. */
        AppointmentResponse nextAppointment,
        long doctorsConsulted,
        long ongoingMedications,
        long prescriptions,
        long ambulanceRequests,
        Activity activity
) {
    /**
     * Activité des 7 derniers jours (aujourd'hui inclus).
     * Les moyennes portent sur les jours où des mesures existent : un jour sans téléphone
     * n'est pas compté comme un jour à 0 pas.
     */
    public record Activity(
            long stepsToday,
            long averageDailySteps,
            /** null si aucune mesure de pas sur la période. */
            LocalDate bestDay,
            long bestDaySteps,
            int daysWithSteps,
            /** null si aucune mesure de fréquence cardiaque sur la période. */
            Double averageHeartRate,
            List<DailyValue> stepsPerDay
    ) {
    }

    public record DailyValue(LocalDate date, double value) {
    }
}
