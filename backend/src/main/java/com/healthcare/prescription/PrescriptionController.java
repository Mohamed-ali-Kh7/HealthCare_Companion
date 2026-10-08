package com.healthcare.prescription;

import com.healthcare.prescription.dto.CreatePrescriptionRequest;
import com.healthcare.prescription.dto.PrescriptionResponse;
import com.healthcare.security.SecurityUser;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/prescriptions")
@RequiredArgsConstructor
public class PrescriptionController {

    private final PrescriptionService prescriptionService;

    @PostMapping
    @PreAuthorize("hasRole('DOCTOR')")
    @ResponseStatus(HttpStatus.CREATED)
    public PrescriptionResponse create(@AuthenticationPrincipal SecurityUser me,
                                       @Valid @RequestBody CreatePrescriptionRequest request) {
        return prescriptionService.create(me.id(), request);
    }

    @GetMapping("/my")
    @PreAuthorize("hasRole('PATIENT')")
    public List<PrescriptionResponse> getMine(@AuthenticationPrincipal SecurityUser me) {
        return prescriptionService.getMine(me.id());
    }

    @GetMapping("/doctor")
    @PreAuthorize("hasRole('DOCTOR')")
    public List<PrescriptionResponse> getIssued(@AuthenticationPrincipal SecurityUser me) {
        return prescriptionService.getIssuedByDoctor(me.id());
    }

    @GetMapping("/patient/{patientId}")
    @PreAuthorize("hasRole('DOCTOR')")
    public List<PrescriptionResponse> getPatientHistory(@PathVariable Long patientId,
                                                        @AuthenticationPrincipal SecurityUser me) {
        return prescriptionService.getPatientHistoryForDoctor(me.id(), patientId);
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('PATIENT', 'DOCTOR', 'ADMIN')")
    public PrescriptionResponse getById(@PathVariable Long id, @AuthenticationPrincipal SecurityUser me) {
        return prescriptionService.getById(me, id);
    }
}
