package com.healthcare.journal;

import com.healthcare.journal.dto.SymptomEntryRequest;
import com.healthcare.journal.dto.SymptomEntryResponse;
import com.healthcare.security.SecurityUser;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;

@RestController
@RequestMapping("/api/journal")
@RequiredArgsConstructor
public class SymptomJournalController {

    private final SymptomJournalService service;

    /** Crée ou remplace l'entrée du jour (un seul enregistrement par jour). */
    @PutMapping("/me")
    @PreAuthorize("hasRole('PATIENT')")
    public SymptomEntryResponse save(@AuthenticationPrincipal SecurityUser me,
                                     @Valid @RequestBody SymptomEntryRequest request) {
        return service.save(me.id(), request);
    }

    @GetMapping("/me")
    @PreAuthorize("hasRole('PATIENT')")
    public List<SymptomEntryResponse> getMine(@AuthenticationPrincipal SecurityUser me,
                                              @RequestParam(defaultValue = "30") int days) {
        return service.getMine(me.id(), days);
    }

    @DeleteMapping("/me/{date}")
    @PreAuthorize("hasRole('PATIENT')")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@AuthenticationPrincipal SecurityUser me,
                       @PathVariable @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        service.deleteMine(me.id(), date);
    }

    @GetMapping("/patients/{patientId}")
    @PreAuthorize("hasRole('DOCTOR')")
    public List<SymptomEntryResponse> getForPatient(@AuthenticationPrincipal SecurityUser me,
                                                    @PathVariable Long patientId,
                                                    @RequestParam(defaultValue = "30") int days) {
        return service.getForDoctor(me.id(), patientId, days);
    }
}
