package com.healthcare.auth;

import com.healthcare.auth.dto.*;
import com.healthcare.doctor.DoctorService;
import com.healthcare.patient.PatientService;
import com.healthcare.pharmacy.PharmacyService;
import com.healthcare.security.JwtService;
import com.healthcare.security.SecurityUser;
import com.healthcare.user.Role;
import com.healthcare.user.User;
import com.healthcare.user.UserService;
import com.healthcare.user.dto.UserResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Inscription : le compte (User) et le profil métier sont créés dans la MÊME transaction.
 * Si la création du profil échoue (spécialité inexistante...), le compte est annulé aussi.
 */
@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserService userService;
    private final PatientService patientService;
    private final DoctorService doctorService;
    private final PharmacyService pharmacyService;
    private final AuthenticationManager authenticationManager;
    private final JwtService jwtService;

    /** Patient : compte actif immédiatement, connecté dans la foulée. */
    @Transactional
    public AuthResponse registerPatient(RegisterPatientRequest r) {
        User user = userService.createUser(r.email(), r.password(), Role.PATIENT, true);
        patientService.createProfile(user, r.firstName(), r.lastName(), r.phone(), r.dateOfBirth());
        return issueToken(SecurityUser.from(user), UserResponse.from(user));
    }

    /** Médecin : compte créé désactivé, en attente de validation par un administrateur. */
    @Transactional
    public UserResponse registerDoctor(RegisterDoctorRequest r) {
        User user = userService.createUser(r.email(), r.password(), Role.DOCTOR, false);
        doctorService.createProfile(user, r.firstName(), r.lastName(), r.phone(), r.specialityId(), r.address());
        return UserResponse.from(user);
    }

    /** Pharmacien : idem, validation de l'officine par l'administrateur. */
    @Transactional
    public UserResponse registerPharmacist(RegisterPharmacistRequest r) {
        User user = userService.createUser(r.email(), r.password(), Role.PHARMACIST, false);
        pharmacyService.createForPharmacist(user, r.pharmacyName(), r.address(), r.phone(),
                r.latitude(), r.longitude());
        return UserResponse.from(user);
    }

    public AuthResponse login(LoginRequest r) {
        Authentication authentication = authenticationManager.authenticate(
                UsernamePasswordAuthenticationToken.unauthenticated(r.email().trim().toLowerCase(), r.password()));
        SecurityUser principal = (SecurityUser) authentication.getPrincipal();
        return issueToken(principal, userService.getById(principal.id()));
    }

    @Transactional(readOnly = true)
    public UserResponse me(Long userId) {
        return userService.getById(userId);
    }

    private AuthResponse issueToken(SecurityUser user, UserResponse userResponse) {
        return AuthResponse.bearer(jwtService.generateToken(user), jwtService.getExpirationSeconds(), userResponse);
    }
}
