package com.healthcare.patient;

import com.healthcare.patient.dto.PatientResponse;
import com.healthcare.patient.dto.UpdatePatientRequest;
import com.healthcare.security.SecurityUser;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/patients")
@RequiredArgsConstructor
public class PatientController {

    private final PatientService patientService;

    @GetMapping("/me")
    @PreAuthorize("hasRole('PATIENT')")
    public PatientResponse getMyProfile(@AuthenticationPrincipal SecurityUser me) {
        return patientService.getMyProfile(me.id());
    }

    @PutMapping("/me")
    @PreAuthorize("hasRole('PATIENT')")
    public PatientResponse updateMyProfile(@AuthenticationPrincipal SecurityUser me,
                                           @Valid @RequestBody UpdatePatientRequest request) {
        return patientService.updateMyProfile(me.id(), request);
    }

    /** Patients suivis par le médecin connecté. */
    @GetMapping("/my-patients")
    @PreAuthorize("hasRole('DOCTOR')")
    public List<PatientResponse> getMyPatients(@AuthenticationPrincipal SecurityUser me) {
        return patientService.getPatientsOfDoctor(me.id());
    }

    /** Médecin (si relation de soin) ou admin. */
    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('DOCTOR', 'ADMIN')")
    public PatientResponse getById(@PathVariable Long id, @AuthenticationPrincipal SecurityUser me) {
        return patientService.getForUser(me, id);
    }
}
