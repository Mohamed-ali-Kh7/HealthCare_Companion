package com.healthcare.telemonitoring;

import com.healthcare.security.SecurityUser;
import com.healthcare.telemonitoring.dto.DailySummaryResponse;
import com.healthcare.telemonitoring.dto.SensorBatchRequest;
import com.healthcare.telemonitoring.dto.SensorBatchResult;
import com.healthcare.telemonitoring.dto.SensorSeriesResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.List;

@RestController
@RequestMapping("/api/sensor-data")
@RequiredArgsConstructor
public class TelemonitoringController {

    private final TelemonitoringService telemonitoringService;

    // ---------------------------------------------------------------- Patient

    @PostMapping
    @PreAuthorize("hasRole('PATIENT')")
    @ResponseStatus(HttpStatus.CREATED)
    public SensorBatchResult ingest(@AuthenticationPrincipal SecurityUser me,
                                    @Valid @RequestBody SensorBatchRequest request) {
        return telemonitoringService.ingest(me.id(), request.readings());
    }

    /** /api/sensor-data/my?type=HEART_RATE&from=2026-10-01T00:00:00Z&to=2026-10-07T23:59:59Z */
    @GetMapping("/my")
    @PreAuthorize("hasRole('PATIENT')")
    public SensorSeriesResponse getMySeries(
            @AuthenticationPrincipal SecurityUser me,
            @RequestParam SensorType type,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant to) {
        return telemonitoringService.getMySeries(me.id(), type, from, to);
    }

    @GetMapping("/my/summary")
    @PreAuthorize("hasRole('PATIENT')")
    public List<DailySummaryResponse> getMySummary(@AuthenticationPrincipal SecurityUser me,
                                                   @RequestParam SensorType type,
                                                   @RequestParam(defaultValue = "7") int days) {
        return telemonitoringService.getMySummary(me.id(), type, days);
    }

    // ---------------------------------------------------------------- Médecin traitant

    @GetMapping("/patients/{patientId}")
    @PreAuthorize("hasRole('DOCTOR')")
    public SensorSeriesResponse getPatientSeries(
            @PathVariable Long patientId,
            @AuthenticationPrincipal SecurityUser me,
            @RequestParam SensorType type,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant to) {
        return telemonitoringService.getPatientSeries(me.id(), patientId, type, from, to);
    }

    @GetMapping("/patients/{patientId}/summary")
    @PreAuthorize("hasRole('DOCTOR')")
    public List<DailySummaryResponse> getPatientSummary(@PathVariable Long patientId,
                                                        @AuthenticationPrincipal SecurityUser me,
                                                        @RequestParam SensorType type,
                                                        @RequestParam(defaultValue = "7") int days) {
        return telemonitoringService.getPatientSummary(me.id(), patientId, type, days);
    }
}
