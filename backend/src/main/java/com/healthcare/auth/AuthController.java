package com.healthcare.auth;

import com.healthcare.auth.dto.*;
import com.healthcare.security.SecurityUser;
import com.healthcare.user.dto.UserResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;

    @PostMapping("/register/patient")
    @ResponseStatus(HttpStatus.CREATED)
    public AuthResponse registerPatient(@Valid @RequestBody RegisterPatientRequest request) {
        return authService.registerPatient(request);
    }

    /** 202 : compte créé mais en attente de validation par un administrateur. */
    @PostMapping("/register/doctor")
    @ResponseStatus(HttpStatus.ACCEPTED)
    public UserResponse registerDoctor(@Valid @RequestBody RegisterDoctorRequest request) {
        return authService.registerDoctor(request);
    }

    @PostMapping("/register/pharmacist")
    @ResponseStatus(HttpStatus.ACCEPTED)
    public UserResponse registerPharmacist(@Valid @RequestBody RegisterPharmacistRequest request) {
        return authService.registerPharmacist(request);
    }

    @PostMapping("/login")
    public AuthResponse login(@Valid @RequestBody LoginRequest request) {
        return authService.login(request);
    }

    /** Utilisé par Flutter au démarrage pour vérifier que le token stocké est encore valide. */
    @GetMapping("/me")
    public UserResponse me(@AuthenticationPrincipal SecurityUser me) {
        return authService.me(me.id());
    }
}
