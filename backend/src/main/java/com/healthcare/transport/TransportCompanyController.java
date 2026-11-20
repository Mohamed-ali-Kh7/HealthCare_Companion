package com.healthcare.transport;

import com.healthcare.security.SecurityUser;
import com.healthcare.transport.dto.TransportDtos.*;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/transport")
@RequiredArgsConstructor
public class TransportCompanyController {

    private final TransportCompanyService service;

    /** Patient : sociétés conventionnées qui desservent le point de prise en charge. */
    @GetMapping("/companies/nearby")
    @PreAuthorize("hasAnyRole('PATIENT','DOCTOR')")
    public List<CompanyResponse> nearby(@RequestParam double lat, @RequestParam double lng,
                                        @RequestParam(required = false) Double radiusKm) {
        return service.findNearby(lat, lng, radiusKm);
    }

    // --- Société

    @GetMapping("/companies/me")
    @PreAuthorize("hasRole('AMBULANCE_COMPANY')")
    public CompanyResponse me(@AuthenticationPrincipal SecurityUser me) {
        return service.getMine(me.id());
    }

    @PutMapping("/companies/me")
    @PreAuthorize("hasRole('AMBULANCE_COMPANY')")
    public CompanyResponse updateMe(@AuthenticationPrincipal SecurityUser me,
                                    @Valid @RequestBody UpdateCompanyRequest request) {
        return service.updateMine(me.id(), request);
    }

    @GetMapping("/vehicles")
    @PreAuthorize("hasRole('AMBULANCE_COMPANY')")
    public List<VehicleResponse> vehicles(@AuthenticationPrincipal SecurityUser me) {
        return service.myVehicles(me.id());
    }

    @PostMapping("/vehicles")
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasRole('AMBULANCE_COMPANY')")
    public VehicleResponse addVehicle(@AuthenticationPrincipal SecurityUser me, @Valid @RequestBody VehicleRequest request) {
        return service.addVehicle(me.id(), request);
    }

    @PutMapping("/vehicles/{id}")
    @PreAuthorize("hasRole('AMBULANCE_COMPANY')")
    public VehicleResponse updateVehicle(@AuthenticationPrincipal SecurityUser me, @PathVariable Long id,
                                         @Valid @RequestBody VehicleRequest request) {
        return service.updateVehicle(me.id(), id, request);
    }

    @PutMapping("/vehicles/{id}/service")
    @PreAuthorize("hasRole('AMBULANCE_COMPANY')")
    public VehicleResponse setInService(@AuthenticationPrincipal SecurityUser me, @PathVariable Long id,
                                        @Valid @RequestBody InServiceRequest request) {
        return service.setInService(me.id(), id, request.inService());
    }
}
