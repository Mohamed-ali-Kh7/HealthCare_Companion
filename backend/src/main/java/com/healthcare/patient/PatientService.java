package com.healthcare.patient;

import com.healthcare.appointment.CareAccessService;
import com.healthcare.common.exception.ResourceNotFoundException;
import com.healthcare.doctor.Doctor;
import com.healthcare.doctor.DoctorService;
import com.healthcare.patient.dto.PatientResponse;
import com.healthcare.patient.dto.UpdatePatientRequest;
import com.healthcare.security.SecurityUser;
import com.healthcare.user.Role;
import com.healthcare.user.User;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.Comparator;
import java.util.List;

@Service
@RequiredArgsConstructor
public class PatientService {

    private final PatientRepository patientRepository;
    private final DoctorService doctorService;
    private final CareAccessService careAccessService;

    @Transactional
    public Patient createProfile(User user, String firstName, String lastName, String phone, LocalDate dateOfBirth) {
        return patientRepository.save(new Patient(user, firstName.trim(), lastName.trim(), phone, dateOfBirth));
    }

    @Transactional(readOnly = true)
    public PatientResponse getMyProfile(Long userId) {
        return PatientResponse.from(getEntityByUserId(userId));
    }

    @Transactional
    public PatientResponse updateMyProfile(Long userId, UpdatePatientRequest request) {
        Patient patient = getEntityByUserId(userId);
        patient.setFirstName(request.firstName().trim());
        patient.setLastName(request.lastName().trim());
        patient.setPhone(request.phone());
        patient.setDateOfBirth(request.dateOfBirth());
        patient.setBloodGroup(blankToNull(request.bloodGroup()));
        patient.setAllergies(blankToNull(request.allergies()));
        return PatientResponse.from(patient);
    }

    /**
     * Admin : accès complet. Médecin : uniquement s'il suit ce patient
     * (rendez-vous en attente, accepté ou terminé).
     */
    @Transactional(readOnly = true)
    public PatientResponse getForUser(SecurityUser me, Long patientId) {
        if (me.hasRole(Role.DOCTOR)) {
            Doctor doctor = doctorService.getEntityByUserId(me.id());
            careAccessService.assertCanViewPatient(doctor.getId(), patientId);
        } else if (!me.hasRole(Role.ADMIN)) {
            throw new AccessDeniedException("Accès refusé");
        }
        return PatientResponse.from(patientRepository.findWithUserById(patientId)
                .orElseThrow(() -> new ResourceNotFoundException("Patient", patientId)));
    }

    /** Liste des patients suivis par le médecin connecté. */
    @Transactional(readOnly = true)
    public List<PatientResponse> getPatientsOfDoctor(Long doctorUserId) {
        Doctor doctor = doctorService.getEntityByUserId(doctorUserId);
        List<Long> ids = careAccessService.findPatientIdsOfDoctor(doctor.getId());
        if (ids.isEmpty()) {
            return List.of();
        }
        return patientRepository.findByIdIn(ids).stream()
                .sorted(Comparator.comparing(Patient::getLastName).thenComparing(Patient::getFirstName))
                .map(PatientResponse::from)
                .toList();
    }

    @Transactional(readOnly = true)
    public Patient getEntity(Long id) {
        return patientRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Patient", id));
    }

    @Transactional(readOnly = true)
    public Patient getEntityByUserId(Long userId) {
        return patientRepository.findByUserId(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Profil patient introuvable"));
    }

    @Transactional(readOnly = true)
    public long count() {
        return patientRepository.count();
    }

    private static String blankToNull(String value) {
        return (value == null || value.isBlank()) ? null : value.trim();
    }
}
