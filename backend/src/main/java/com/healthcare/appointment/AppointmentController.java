package com.healthcare.appointment;

import com.healthcare.appointment.dto.AppointmentResponse;
import com.healthcare.appointment.dto.CreateAppointmentRequest;
import com.healthcare.appointment.dto.DoctorNoteRequest;
import com.healthcare.common.dto.PageResponse;
import com.healthcare.security.SecurityUser;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

@RestController
@RequestMapping("/api/appointments")
@RequiredArgsConstructor
public class AppointmentController {

    private final AppointmentService appointmentService;

    /** Créneaux libres : /api/appointments/slots?doctorId=3&date=2026-10-12 */
    @GetMapping("/slots")
    public List<LocalDateTime> getSlots(@RequestParam Long doctorId,
                                        @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        return appointmentService.getAvailableSlots(doctorId, date);
    }

    // ---------------------------------------------------------------- Patient

    @PostMapping
    @PreAuthorize("hasRole('PATIENT')")
    @ResponseStatus(HttpStatus.CREATED)
    public AppointmentResponse create(@AuthenticationPrincipal SecurityUser me,
                                      @Valid @RequestBody CreateAppointmentRequest request) {
        return appointmentService.create(me.id(), request);
    }

    @GetMapping("/my")
    @PreAuthorize("hasRole('PATIENT')")
    public List<AppointmentResponse> getMyAppointments(@AuthenticationPrincipal SecurityUser me) {
        return appointmentService.getMyAppointments(me.id());
    }

    @PutMapping("/{id}/cancel")
    @PreAuthorize("hasRole('PATIENT')")
    public AppointmentResponse cancel(@PathVariable Long id, @AuthenticationPrincipal SecurityUser me) {
        return appointmentService.cancel(me.id(), id);
    }

    // ---------------------------------------------------------------- Médecin

    /** Planning : /api/appointments/doctor?status=PENDING&from=2026-10-01&to=2026-10-31 */
    @GetMapping("/doctor")
    @PreAuthorize("hasRole('DOCTOR')")
    public List<AppointmentResponse> getDoctorAppointments(
            @AuthenticationPrincipal SecurityUser me,
            @RequestParam(required = false) AppointmentStatus status,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        return appointmentService.getDoctorAppointments(me.id(), status, from, to);
    }

    @PutMapping("/{id}/accept")
    @PreAuthorize("hasRole('DOCTOR')")
    public AppointmentResponse accept(@PathVariable Long id, @AuthenticationPrincipal SecurityUser me) {
        return appointmentService.accept(me.id(), id);
    }

    @PutMapping("/{id}/reject")
    @PreAuthorize("hasRole('DOCTOR')")
    public AppointmentResponse reject(@PathVariable Long id, @AuthenticationPrincipal SecurityUser me,
                                      @Valid @RequestBody(required = false) DoctorNoteRequest request) {
        return appointmentService.reject(me.id(), id, request == null ? null : request.note());
    }

    @PutMapping("/{id}/complete")
    @PreAuthorize("hasRole('DOCTOR')")
    public AppointmentResponse complete(@PathVariable Long id, @AuthenticationPrincipal SecurityUser me,
                                        @Valid @RequestBody(required = false) DoctorNoteRequest request) {
        return appointmentService.complete(me.id(), id, request == null ? null : request.note());
    }

    // ---------------------------------------------------------------- Admin

    @GetMapping
    @PreAuthorize("hasRole('ADMIN')")
    public PageResponse<AppointmentResponse> findAll(
            @RequestParam(required = false) AppointmentStatus status,
            @PageableDefault(size = 20, sort = "appointmentDate", direction = Sort.Direction.DESC) Pageable pageable) {
        return appointmentService.findAll(status, pageable);
    }
}
