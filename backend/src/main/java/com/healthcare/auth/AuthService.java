package com.healthcare.auth;

import com.healthcare.auth.code.AuthCodeService;
import com.healthcare.auth.code.CodePurpose;
import com.healthcare.auth.dto.*;
import com.healthcare.common.exception.BusinessRuleException;
import com.healthcare.doctor.DoctorService;
import com.healthcare.mail.MailService;
import com.healthcare.patient.PatientService;
import com.healthcare.pharmacy.PharmacyService;
import com.healthcare.security.JwtService;
import com.healthcare.security.SecurityUser;
import com.healthcare.transport.TransportCompanyService;
import com.healthcare.user.Role;
import com.healthcare.user.User;
import com.healthcare.user.UserService;
import com.healthcare.user.dto.UserResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.DisabledException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Inscription : le compte (User) et le profil métier sont créés dans la MÊME transaction.
 * Si la création du profil échoue (spécialité inexistante...), le compte est annulé aussi.
 * <p>
 * Si l'envoi d'e-mails est activé (MAIL_ENABLED), chaque inscription doit être confirmée par un
 * code à 6 chiffres reçu par e-mail avant la première connexion.
 */
@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserService userService;
    private final PatientService patientService;
    private final DoctorService doctorService;
    private final PharmacyService pharmacyService;
    private final TransportCompanyService transportCompanyService;
    private final AuthenticationManager authenticationManager;
    private final JwtService jwtService;
    private final AuthCodeService authCodeService;
    private final MailService mailService;

    /**
     * Patient : compte actif immédiatement. Connecté dans la foulée, sauf si son e-mail
     * doit d'abord être vérifié (réponse sans token).
     */
    @Transactional
    public AuthResponse registerPatient(RegisterPatientRequest r) {
        User user = userService.createUser(r.email(), r.password(), Role.PATIENT, true);
        patientService.createProfile(user, r.firstName(), r.lastName(), r.phone(), r.dateOfBirth());
        if (requireEmailVerification(user)) {
            return AuthResponse.pending(UserResponse.from(user));
        }
        return issueToken(SecurityUser.from(user), UserResponse.from(user));
    }

    /** Médecin : compte créé désactivé, en attente de validation par un administrateur. */
    @Transactional
    public UserResponse registerDoctor(RegisterDoctorRequest r) {
        User user = userService.createUser(r.email(), r.password(), Role.DOCTOR, false);
        doctorService.createProfile(user, r.firstName(), r.lastName(), r.phone(), r.specialityId(), r.address());
        requireEmailVerification(user);
        return UserResponse.from(user);
    }

    /** Pharmacien : idem, validation de l'officine par l'administrateur. */
    @Transactional
    public UserResponse registerPharmacist(RegisterPharmacistRequest r) {
        User user = userService.createUser(r.email(), r.password(), Role.PHARMACIST, false);
        pharmacyService.createForPharmacist(user, r.pharmacyName(), r.address(), r.phone(),
                r.latitude(), r.longitude());
        requireEmailVerification(user);
        return UserResponse.from(user);
    }

    @Transactional
    public UserResponse registerAmbulanceCompany(RegisterAmbulanceCompanyRequest r) {
        User user = userService.createUser(r.email(), r.password(), Role.AMBULANCE_COMPANY, false);
        transportCompanyService.createForUser(user, r.companyName(), r.conventionNumber(), r.address(), r.city(),
                r.phone().trim(), r.latitude(), r.longitude());
        requireEmailVerification(user);
        return UserResponse.from(user);
    }

    /**
     * L'e-mail non vérifié est signalé avant le compte en attente de validation, et toujours
     * APRÈS le contrôle du mot de passe. Un nouveau code est alors envoyé (sauf envoi très récent).
     */
    public AuthResponse login(LoginRequest r) {
        String email = r.email().trim().toLowerCase();
        Authentication authentication;
        try {
            authentication = authenticationManager.authenticate(
                    UsernamePasswordAuthenticationToken.unauthenticated(email, r.password()));
        } catch (DisabledException e) {
            User user = userService.findEntityByEmail(email).orElseThrow(() -> e);
            rejectIfEmailNotVerified(user);
            throw e;
        }
        SecurityUser principal = (SecurityUser) authentication.getPrincipal();
        User user = userService.getEntity(principal.id());
        rejectIfEmailNotVerified(user);
        return issueToken(principal, UserResponse.from(user));
    }

    /** Code reçu après l'inscription : active l'adresse et ouvre la session si le compte est actif. */
    @Transactional
    public AuthResponse verifyEmail(VerifyEmailRequest r) {
        User user = userService.findEntityByEmail(r.email()).orElseThrow(AuthCodeService::invalidCode);
        if (user.isEmailVerified()) {
            throw new BusinessRuleException("EMAIL_ALREADY_VERIFIED", "Adresse e-mail déjà vérifiée : connectez-vous.");
        }
        authCodeService.verify(user, CodePurpose.EMAIL_VERIFICATION, r.code());
        user.setEmailVerified(true);
        UserResponse response = UserResponse.from(user);
        return user.isEnabled() ? issueToken(SecurityUser.from(user), response) : AuthResponse.pending(response);
    }

    /** Toujours silencieux (aucune indication sur l'existence du compte). */
    @Transactional
    public void resendVerification(EmailRequest r) {
        if (!mailService.isEnabled()) return;
        userService.findEntityByEmail(r.email())
                .filter(user -> !user.isEmailVerified())
                .ifPresent(user -> authCodeService.issue(user, CodePurpose.EMAIL_VERIFICATION));
    }

    /** Toujours silencieux (aucune indication sur l'existence du compte). */
    @Transactional
    public void forgotPassword(EmailRequest r) {
        userService.findEntityByEmail(r.email())
                .ifPresent(user -> authCodeService.issue(user, CodePurpose.PASSWORD_RESET));
    }

    /** Le code prouve que l'utilisateur possède l'adresse : elle est donc aussi marquée vérifiée. */
    @Transactional
    public void resetPassword(ResetPasswordRequest r) {
        User user = userService.findEntityByEmail(r.email()).orElseThrow(AuthCodeService::invalidCode);
        authCodeService.verify(user, CodePurpose.PASSWORD_RESET, r.code());
        userService.resetPassword(user, r.newPassword());
        user.setEmailVerified(true);
    }

    @Transactional(readOnly = true)
    public UserResponse me(Long userId) {
        return userService.getById(userId);
    }

    /** @return true si l'utilisateur doit confirmer son e-mail (code envoyé). */
    private boolean requireEmailVerification(User user) {
        if (!mailService.isEnabled()) return false;
        user.setEmailVerified(false);
        authCodeService.issue(user, CodePurpose.EMAIL_VERIFICATION);
        return true;
    }

    /** Si l'envoi d'e-mails est désactivé, la vérification n'est pas exigée (sinon personne ne pourrait la faire). */
    private void rejectIfEmailNotVerified(User user) {
        if (user.isEmailVerified() || !mailService.isEnabled()) return;
        authCodeService.issue(user, CodePurpose.EMAIL_VERIFICATION);
        throw new EmailNotVerifiedException();
    }

    private AuthResponse issueToken(SecurityUser user, UserResponse userResponse) {
        return AuthResponse.bearer(jwtService.generateToken(user), jwtService.getExpirationSeconds(), userResponse);
    }
}
