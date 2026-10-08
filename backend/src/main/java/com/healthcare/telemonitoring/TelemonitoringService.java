package com.healthcare.telemonitoring;

import com.healthcare.appointment.CareAccessService;
import com.healthcare.common.exception.BusinessRuleException;
import com.healthcare.doctor.Doctor;
import com.healthcare.doctor.DoctorService;
import com.healthcare.patient.Patient;
import com.healthcare.patient.PatientService;
import com.healthcare.telemonitoring.dto.*;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.*;
import java.time.temporal.ChronoUnit;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class TelemonitoringService {

    /** Tolérance pour l'horloge du téléphone légèrement en avance. */
    private static final Duration FUTURE_TOLERANCE = Duration.ofMinutes(5);
    /** Fenêtre maximale d'une requête de série temporelle. */
    private static final Duration MAX_RANGE = Duration.ofDays(31);
    private static final int MAX_SUMMARY_DAYS = 90;

    private final SensorDataRepository sensorDataRepository;
    private final PatientService patientService;
    private final DoctorService doctorService;
    private final CareAccessService careAccessService;
    private final Clock clock;

    // ---------------------------------------------------------------- Collecte (patient)

    /**
     * Enregistre un lot de mesures. Idempotent : les mesures déjà reçues (même type,
     * même horodatage) sont ignorées, ce qui permet au mobile de renvoyer un lot sans risque.
     */
    @Transactional
    public SensorBatchResult ingest(Long patientUserId, List<SensorReadingRequest> readings) {
        Patient patient = patientService.getEntityByUserId(patientUserId);
        Instant latestAllowed = clock.instant().plus(FUTURE_TOLERANCE);

        for (SensorReadingRequest r : readings) {
            if (r.recordedAt().isAfter(latestAllowed)) {
                throw new BusinessRuleException("READING_IN_FUTURE", "Mesure horodatée dans le futur : " + r.recordedAt());
            }
            if (!r.type().accepts(r.value())) {
                throw new BusinessRuleException("READING_OUT_OF_RANGE",
                        "Valeur hors limites pour " + r.type() + " : " + r.value());
            }
        }

        int accepted = 0;
        int duplicates = 0;
        Map<SensorType, List<SensorReadingRequest>> byType = readings.stream()
                .collect(Collectors.groupingBy(SensorReadingRequest::type));

        for (Map.Entry<SensorType, List<SensorReadingRequest>> entry : byType.entrySet()) {
            SensorType type = entry.getKey();
            Set<Instant> instants = entry.getValue().stream()
                    .map(r -> r.recordedAt().truncatedTo(ChronoUnit.MILLIS))
                    .collect(Collectors.toSet());
            Set<Instant> seen = new HashSet<>(sensorDataRepository.findExistingInstants(patient.getId(), type, instants));

            List<SensorData> toSave = new ArrayList<>();
            for (SensorReadingRequest r : entry.getValue()) {
                Instant at = r.recordedAt().truncatedTo(ChronoUnit.MILLIS);
                if (seen.add(at)) {
                    toSave.add(new SensorData(patient, type, r.value(), at));
                } else {
                    duplicates++;
                }
            }
            sensorDataRepository.saveAll(toSave);
            accepted += toSave.size();
        }
        return new SensorBatchResult(accepted, duplicates);
    }

    // ---------------------------------------------------------------- Lecture

    @Transactional(readOnly = true)
    public SensorSeriesResponse getMySeries(Long patientUserId, SensorType type, Instant from, Instant to) {
        Patient patient = patientService.getEntityByUserId(patientUserId);
        return series(patient.getId(), type, from, to);
    }

    @Transactional(readOnly = true)
    public List<DailySummaryResponse> getMySummary(Long patientUserId, SensorType type, int days) {
        Patient patient = patientService.getEntityByUserId(patientUserId);
        return dailySummary(patient.getId(), type, days);
    }

    /** Médecin traitant uniquement (rendez-vous accepté ou terminé avec ce patient). */
    @Transactional(readOnly = true)
    public SensorSeriesResponse getPatientSeries(Long doctorUserId, Long patientId,
                                                 SensorType type, Instant from, Instant to) {
        assertTreatingDoctor(doctorUserId, patientId);
        return series(patientId, type, from, to);
    }

    @Transactional(readOnly = true)
    public List<DailySummaryResponse> getPatientSummary(Long doctorUserId, Long patientId, SensorType type, int days) {
        assertTreatingDoctor(doctorUserId, patientId);
        return dailySummary(patientId, type, days);
    }

    @Transactional(readOnly = true)
    public long countReceivedSince(Instant since) {
        return sensorDataRepository.countByCreatedAtAfter(since);
    }

    // ---------------------------------------------------------------- Interne

    private void assertTreatingDoctor(Long doctorUserId, Long patientId) {
        Doctor doctor = doctorService.getEntityByUserId(doctorUserId);
        careAccessService.assertCanTreatPatient(doctor.getId(), patientId);
    }

    private SensorSeriesResponse series(Long patientId, SensorType type, Instant from, Instant to) {
        Instant end = to != null ? to : clock.instant();
        Instant start = from != null ? from : end.minus(Duration.ofDays(1));
        if (!start.isBefore(end)) {
            throw new BusinessRuleException("INVALID_DATE_RANGE", "'from' doit précéder 'to'");
        }
        if (Duration.between(start, end).compareTo(MAX_RANGE) > 0) {
            throw new BusinessRuleException("RANGE_TOO_LARGE", "Période maximale : 31 jours (utilisez /summary)");
        }
        List<SensorPointResponse> points = sensorDataRepository
                .findTop5000ByPatientIdAndSensorTypeAndRecordedAtBetweenOrderByRecordedAtAsc(patientId, type, start, end)
                .stream()
                .map(s -> new SensorPointResponse(s.getRecordedAt(), s.getValue()))
                .toList();
        return new SensorSeriesResponse(type, type.unit(), points);
    }

    /** Agrégation journalière dans le fuseau métier (un jour = minuit à minuit, heure de Tunis). */
    private List<DailySummaryResponse> dailySummary(Long patientId, SensorType type, int days) {
        int span = Math.max(1, Math.min(days, MAX_SUMMARY_DAYS));
        ZoneId zone = clock.getZone();
        LocalDate today = LocalDate.now(clock);
        LocalDate firstDay = today.minusDays(span - 1L);
        Instant start = firstDay.atStartOfDay(zone).toInstant();
        Instant end = today.plusDays(1).atStartOfDay(zone).toInstant();

        Map<LocalDate, DoubleSummaryStatistics> stats = new TreeMap<>();
        sensorDataRepository
                .findTop5000ByPatientIdAndSensorTypeAndRecordedAtBetweenOrderByRecordedAtAsc(patientId, type, start, end)
                .forEach(s -> stats.computeIfAbsent(LocalDate.ofInstant(s.getRecordedAt(), zone),
                        d -> new DoubleSummaryStatistics()).accept(s.getValue()));

        List<DailySummaryResponse> result = new ArrayList<>();
        for (LocalDate day = firstDay; !day.isAfter(today); day = day.plusDays(1)) {
            DoubleSummaryStatistics s = stats.get(day);
            if (s == null) {
                result.add(new DailySummaryResponse(day, 0, 0, 0, 0, 0));
            } else {
                result.add(new DailySummaryResponse(day, s.getCount(), s.getMin(), s.getMax(),
                        Math.round(s.getAverage() * 10.0) / 10.0, s.getSum()));
            }
        }
        return result;
    }
}
