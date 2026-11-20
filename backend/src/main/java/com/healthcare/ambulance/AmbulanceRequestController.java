package com.healthcare.ambulance;

import com.healthcare.ambulance.dto.AmbulanceRequestResponse;
import com.healthcare.ambulance.dto.CreateAmbulanceRequest;
import com.healthcare.appointment.dto.DoctorNoteRequest;
import com.healthcare.security.SecurityUser;
import com.healthcare.user.Role;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/ambulance-requests")
@RequiredArgsConstructor
public class AmbulanceRequestController {

    private final AmbulanceRequestService service;

    // ---------------------------------------------------------------- Patient

    @PostMapping
    @PreAuthorize("hasRole('PATIENT')")
    @ResponseStatus(HttpStatus.CREATED)
    public AmbulanceRequestResponse create(@AuthenticationPrincipal SecurityUser me,
                                           @Valid @RequestBody CreateAmbulanceRequest request) {
        return service.create(me.id(), request);
    }

    @GetMapping("/my")
    @PreAuthorize("hasRole('PATIENT')")
    public List<AmbulanceRequestResponse> getMine(@AuthenticationPrincipal SecurityUser me) {
        return service.getMine(me.id());
    }

    @PutMapping("/{id}/cancel")
    @PreAuthorize("hasRole('PATIENT')")
    public AmbulanceRequestResponse cancel(@PathVariable Long id, @AuthenticationPrincipal SecurityUser me) {
        return service.cancel(me.id(), id);
    }

    /** Urgence résolue / transport effectué : par le patient ou par le médecin référent. */
    @PutMapping("/{id}/close")
    @PreAuthorize("hasAnyRole('PATIENT', 'DOCTOR')")
    public AmbulanceRequestResponse close(@PathVariable Long id, @AuthenticationPrincipal SecurityUser me) {
        return me.hasRole(Role.PATIENT) ? service.closeByPatient(me.id(), id) : service.closeByDoctor(me.id(), id);
    }

    // ---------------------------------------------------------------- Médecin

    @GetMapping("/doctor")
    @PreAuthorize("hasRole('DOCTOR')")
    public List<AmbulanceRequestResponse> getForDoctor(@AuthenticationPrincipal SecurityUser me) {
        return service.getForDoctor(me.id());
    }

    @PutMapping("/{id}/take-charge")
    @PreAuthorize("hasRole('DOCTOR')")
    public AmbulanceRequestResponse takeCharge(@PathVariable Long id, @AuthenticationPrincipal SecurityUser me,
                                               @Valid @RequestBody(required = false) DoctorNoteRequest request) {
        return service.takeCharge(me.id(), id, request == null ? null : request.note());
    }

    @PutMapping("/{id}/approve")
    @PreAuthorize("hasRole('DOCTOR')")
    public AmbulanceRequestResponse approve(@PathVariable Long id, @AuthenticationPrincipal SecurityUser me,
                                            @Valid @RequestBody(required = false) DoctorNoteRequest request) {
        return service.approve(me.id(), id, request == null ? null : request.note());
    }

    @PutMapping("/{id}/reject")
    @PreAuthorize("hasRole('DOCTOR')")
    public AmbulanceRequestResponse reject(@PathVariable Long id, @AuthenticationPrincipal SecurityUser me,
                                           @Valid @RequestBody(required = false) DoctorNoteRequest request) {
        return service.reject(me.id(), id, request == null ? null : request.note());
    }

    // ---------------------------------------------------------------- Ambulance conventionnée

    public record ChooseCompanyRequest(@NotNull Long companyId) {
    }

    public record AcceptMissionRequest(@NotNull Long vehicleId, @Size(max = 500) String note) {
    }

    /** Patient : confie le transport validé à une société conventionnée. */
    @PutMapping("/{id}/company")
    @PreAuthorize("hasRole('PATIENT')")
    public AmbulanceRequestResponse chooseCompany(@PathVariable Long id, @AuthenticationPrincipal SecurityUser me,
                                                  @Valid @RequestBody ChooseCompanyRequest request) {
        return service.chooseCompany(me.id(), id, request.companyId());
    }

    @GetMapping("/company")
    @PreAuthorize("hasRole('AMBULANCE_COMPANY')")
    public List<AmbulanceRequestResponse> getForCompany(@AuthenticationPrincipal SecurityUser me) {
        return service.getForCompany(me.id());
    }

    @PutMapping("/{id}/mission/accept")
    @PreAuthorize("hasRole('AMBULANCE_COMPANY')")
    public AmbulanceRequestResponse acceptMission(@PathVariable Long id, @AuthenticationPrincipal SecurityUser me,
                                                  @Valid @RequestBody AcceptMissionRequest request) {
        return service.acceptMission(me.id(), id, request.vehicleId(), request.note());
    }

    @PutMapping("/{id}/mission/refuse")
    @PreAuthorize("hasRole('AMBULANCE_COMPANY')")
    public AmbulanceRequestResponse refuseMission(@PathVariable Long id, @AuthenticationPrincipal SecurityUser me,
                                                  @Valid @RequestBody(required = false) DoctorNoteRequest request) {
        return service.refuseMission(me.id(), id, request == null ? null : request.note());
    }

    /** Étape suivante du trajet (en route, sur place, transport en cours, arrivé). */
    @PutMapping("/{id}/mission/advance")
    @PreAuthorize("hasRole('AMBULANCE_COMPANY')")
    public AmbulanceRequestResponse advanceMission(@PathVariable Long id, @AuthenticationPrincipal SecurityUser me) {
        return service.advanceMission(me.id(), id);
    }
}
