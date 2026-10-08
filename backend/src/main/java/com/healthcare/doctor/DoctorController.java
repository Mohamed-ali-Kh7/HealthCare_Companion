package com.healthcare.doctor;

import com.healthcare.common.dto.PageResponse;
import com.healthcare.doctor.dto.AvailabilityResponse;
import com.healthcare.doctor.dto.DoctorResponse;
import com.healthcare.doctor.dto.ReplaceAvailabilitiesRequest;
import com.healthcare.doctor.dto.UpdateDoctorRequest;
import com.healthcare.security.SecurityUser;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/doctors")
@RequiredArgsConstructor
public class DoctorController {

    private final DoctorService doctorService;

    /** Recherche : /api/doctors?q=ben&specialityId=2&page=0&size=20 */
    @GetMapping
    public PageResponse<DoctorResponse> search(@RequestParam(required = false) String q,
                                               @RequestParam(required = false) Long specialityId,
                                               @PageableDefault(size = 20, sort = "lastName",
                                                       direction = Sort.Direction.ASC) Pageable pageable) {
        return doctorService.search(q, specialityId, pageable);
    }

    @GetMapping("/me")
    @PreAuthorize("hasRole('DOCTOR')")
    public DoctorResponse getMyProfile(@AuthenticationPrincipal SecurityUser me) {
        return doctorService.getMyProfile(me.id());
    }

    @PutMapping("/me")
    @PreAuthorize("hasRole('DOCTOR')")
    public DoctorResponse updateMyProfile(@AuthenticationPrincipal SecurityUser me,
                                          @Valid @RequestBody UpdateDoctorRequest request) {
        return doctorService.updateMyProfile(me.id(), request);
    }

    @GetMapping("/me/availabilities")
    @PreAuthorize("hasRole('DOCTOR')")
    public List<AvailabilityResponse> getMyAvailabilities(@AuthenticationPrincipal SecurityUser me) {
        return doctorService.getMyAvailabilities(me.id());
    }

    @PutMapping("/me/availabilities")
    @PreAuthorize("hasRole('DOCTOR')")
    public List<AvailabilityResponse> replaceMyAvailabilities(
            @AuthenticationPrincipal SecurityUser me,
            @Valid @RequestBody ReplaceAvailabilitiesRequest request) {
        return doctorService.replaceMyAvailabilities(me.id(), request.availabilities());
    }

    @GetMapping("/{id}")
    public DoctorResponse getById(@PathVariable Long id) {
        return doctorService.getById(id);
    }

    @GetMapping("/{id}/availabilities")
    public List<AvailabilityResponse> getAvailabilities(@PathVariable Long id) {
        return doctorService.getAvailabilities(id);
    }
}
