package com.healthcare.stats;

import com.healthcare.ambulance.AmbulanceRequestService;
import com.healthcare.appointment.AppointmentService;
import com.healthcare.appointment.AppointmentStatus;
import com.healthcare.appointment.CareAccessService;
import com.healthcare.doctor.Doctor;
import com.healthcare.doctor.DoctorService;
import com.healthcare.medication.MedicationService;
import com.healthcare.patient.Patient;
import com.healthcare.patient.PatientService;
import com.healthcare.prescription.PrescriptionService;
import com.healthcare.stats.dto.DoctorStatsResponse;
import com.healthcare.stats.dto.PatientStatsResponse;
import com.healthcare.telemonitoring.SensorType;
import com.healthcare.telemonitoring.TelemonitoringService;
import com.healthcare.telemonitoring.dto.DailySummaryResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.LocalDate;
import java.util.Comparator;
import java.util.List;
import java.util.Map;

/**
 * Statistiques personnelles du patient et du médecin.
 * Comme le tableau de bord admin, ce module n'a pas de repository : il agrège les compteurs
 * exposés par les services des autres modules.
 */
@Service
@RequiredArgsConstructor
public class StatsService {

    private static final int ACTIVITY_DAYS = 7;
    private static final int PLANNING_DAYS = 7;
    private static final int TOP_MEDICINES = 5;

    private final PatientService patientService;
    private final DoctorService doctorService;
    private final AppointmentService appointmentService;
    private final CareAccessService careAccessService;
    private final PrescriptionService prescriptionService;
    private final MedicationService medicationService;
    private final TelemonitoringService telemonitoringService;
    private final AmbulanceRequestService ambulanceService;
    private final Clock clock;

    // ---------------------------------------------------------------- Patient

    @Transactional(readOnly = true)
    public PatientStatsResponse forPatient(Long patientUserId) {
        Patient patient = patientService.getEntityByUserId(patientUserId);
        Long patientId = patient.getId();
        return new PatientStatsResponse(
                appointmentService.countByStatusForPatient(patientId),
                appointmentService.findNextForPatient(patientId).orElse(null),
                appointmentService.countDoctorsOfPatient(patientId),
                medicationService.countOngoingForPatient(patientId, LocalDate.now(clock)),
                prescriptionService.countForPatient(patientId),
                ambulanceService.countForPatient(patientId),
                activity(patientUserId));
    }

    private PatientStatsResponse.Activity activity(Long patientUserId) {
        List<DailySummaryResponse> steps = telemonitoringService.getMySummary(patientUserId, SensorType.STEPS, ACTIVITY_DAYS);
        List<DailySummaryResponse> heart = telemonitoringService.getMySummary(patientUserId, SensorType.HEART_RATE, ACTIVITY_DAYS);

        // Le résumé couvre chaque jour de la période, du plus ancien à aujourd'hui
        List<DailySummaryResponse> measuredDays = steps.stream().filter(d -> d.count() > 0).toList();
        long stepsToday = steps.isEmpty() ? 0 : Math.round(steps.get(steps.size() - 1).sum());
        long average = measuredDays.isEmpty() ? 0
                : Math.round(measuredDays.stream().mapToDouble(DailySummaryResponse::sum).average().orElse(0));
        DailySummaryResponse best = measuredDays.stream()
                .max(Comparator.comparingDouble(DailySummaryResponse::sum))
                .orElse(null);

        // Moyenne pondérée par le nombre de mesures de chaque jour
        long heartCount = heart.stream().mapToLong(DailySummaryResponse::count).sum();
        Double averageHeartRate = heartCount == 0 ? null
                : round1(heart.stream().mapToDouble(d -> d.avg() * d.count()).sum() / heartCount);

        return new PatientStatsResponse.Activity(
                stepsToday,
                average,
                best == null ? null : best.date(),
                best == null ? 0 : Math.round(best.sum()),
                measuredDays.size(),
                averageHeartRate,
                steps.stream().map(d -> new PatientStatsResponse.DailyValue(d.date(), d.sum())).toList());
    }

    // ---------------------------------------------------------------- Médecin

    @Transactional(readOnly = true)
    public DoctorStatsResponse forDoctor(Long doctorUserId) {
        Doctor doctor = doctorService.getEntityByUserId(doctorUserId);
        Long doctorId = doctor.getId();
        LocalDate today = LocalDate.now(clock);
        LocalDate firstOfMonth = today.withDayOfMonth(1);

        List<Long> patientIds = careAccessService.findPatientIdsOfDoctor(doctorId);
        Map<AppointmentStatus, Long> byStatus = appointmentService.countByStatusForDoctor(doctorId);
        List<DoctorStatsResponse.DailyCount> upcoming = appointmentService
                .countUpcomingPerDayForDoctor(doctorId, PLANNING_DAYS).entrySet().stream()
                .map(e -> new DoctorStatsResponse.DailyCount(e.getKey(), e.getValue()))
                .toList();

        return new DoctorStatsResponse(
                patientIds.size(),
                byStatus,
                upcoming.isEmpty() ? 0 : upcoming.get(0).count(),
                upcoming,
                acceptanceRate(byStatus),
                appointmentService.countCompletedForDoctorSince(doctorId, firstOfMonth),
                prescriptionService.countIssuedByDoctor(doctorId),
                prescriptionService.countIssuedByDoctorSince(doctorId, firstOfMonth),
                prescriptionService.topMedicinesOfDoctor(doctorId, TOP_MEDICINES),
                ambulanceService.countPendingForDoctor(doctorId),
                ambulanceService.countActiveEmergencies(patientIds));
    }

    /** Annulations exclues : c'est une décision du patient, pas du médecin. */
    static Double acceptanceRate(Map<AppointmentStatus, Long> byStatus) {
        long accepted = byStatus.getOrDefault(AppointmentStatus.ACCEPTED, 0L)
                + byStatus.getOrDefault(AppointmentStatus.COMPLETED, 0L);
        long decided = accepted + byStatus.getOrDefault(AppointmentStatus.REJECTED, 0L);
        return decided == 0 ? null : round1(100.0 * accepted / decided);
    }

    private static double round1(double value) {
        return Math.round(value * 10.0) / 10.0;
    }
}
