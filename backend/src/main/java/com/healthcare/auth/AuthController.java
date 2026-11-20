package com.healthcare.auth;

import com.healthcare.auth.dto.*;
import com.healthcare.security.SecurityUser;
import com.healthcare.user.dto.UserResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;

    /** 201 + token : connecté. 202 sans token : saisir le code reçu par e-mail (POST /verify-email). */
    @PostMapping("/register/patient")
    public ResponseEntity<AuthResponse> registerPatient(@Valid @RequestBody RegisterPatientRequest request) {
        AuthResponse response = authService.registerPatient(request);
        return ResponseEntity.status(response.hasSession() ? HttpStatus.CREATED : HttpStatus.ACCEPTED).body(response);
    }

    /** Token renvoyé si le compte est actif ; sinon (validation admin en attente) user seul. */
    @PostMapping("/verify-email")
    public AuthResponse verifyEmail(@Valid @RequestBody VerifyEmailRequest request) {
        return authService.verifyEmail(request);
    }

    /** Toujours 204, que le compte existe ou non. */
    @PostMapping("/resend-verification")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void resendVerification(@Valid @RequestBody EmailRequest request) {
        authService.resendVerification(request);
    }

    /** Toujours 204, que le compte existe ou non : envoie un code de réinitialisation. */
    @PostMapping("/forgot-password")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void forgotPassword(@Valid @RequestBody EmailRequest request) {
        authService.forgotPassword(request);
    }

    @PostMapping("/reset-password")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void resetPassword(@Valid @RequestBody ResetPasswordRequest request) {
        authService.resetPassword(request);
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

    @PostMapping("/register/ambulance-company")
    @ResponseStatus(HttpStatus.ACCEPTED)
    public UserResponse registerAmbulanceCompany(@Valid @RequestBody RegisterAmbulanceCompanyRequest request) {
        return authService.registerAmbulanceCompany(request);
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
