package com.healthcare.medication;

import com.healthcare.medication.dto.MedicationRequest;
import com.healthcare.medication.dto.MedicationResponse;
import com.healthcare.security.SecurityUser;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/** Carnet de suivi du patient connecté. */
@RestController
@RequestMapping("/api/medications")
@PreAuthorize("hasRole('PATIENT')")
@RequiredArgsConstructor
public class MedicationController {

    private final MedicationService medicationService;

    @GetMapping
    public List<MedicationResponse> getMine(@AuthenticationPrincipal SecurityUser me) {
        return medicationService.getMine(me.id());
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public MedicationResponse create(@AuthenticationPrincipal SecurityUser me,
                                     @Valid @RequestBody MedicationRequest request) {
        return medicationService.create(me.id(), request);
    }

    @PutMapping("/{id}")
    public MedicationResponse update(@PathVariable Long id, @AuthenticationPrincipal SecurityUser me,
                                     @Valid @RequestBody MedicationRequest request) {
        return medicationService.update(me.id(), id, request);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id, @AuthenticationPrincipal SecurityUser me) {
        medicationService.delete(me.id(), id);
        return ResponseEntity.noContent().build();
    }
}
