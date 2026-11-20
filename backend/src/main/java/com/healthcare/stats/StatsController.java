package com.healthcare.stats;

import com.healthcare.security.SecurityUser;
import com.healthcare.stats.dto.DoctorStatsResponse;
import com.healthcare.stats.dto.PatientStatsResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** Statistiques personnelles : chacun ne voit que les siennes (l'id vient du token). */
@RestController
@RequestMapping("/api/stats")
@RequiredArgsConstructor
public class StatsController {

    private final StatsService statsService;

    @GetMapping("/patient")
    @PreAuthorize("hasRole('PATIENT')")
    public PatientStatsResponse forPatient(@AuthenticationPrincipal SecurityUser me) {
        return statsService.forPatient(me.id());
    }

    @GetMapping("/doctor")
    @PreAuthorize("hasRole('DOCTOR')")
    public DoctorStatsResponse forDoctor(@AuthenticationPrincipal SecurityUser me) {
        return statsService.forDoctor(me.id());
    }
}
