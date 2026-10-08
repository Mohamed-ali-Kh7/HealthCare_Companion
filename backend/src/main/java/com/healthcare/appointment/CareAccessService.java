package com.healthcare.appointment;

import lombok.RequiredArgsConstructor;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.EnumSet;
import java.util.List;
import java.util.Set;

/**
 * Règle de confidentialité centrale : un médecin n'accède aux données d'un patient
 * (profil, ordonnances, capteurs) que s'il existe une relation de soin, matérialisée
 * par un rendez-vous.
 *
 * Ne dépend que du repository des rendez-vous : utilisable par les modules patient,
 * ordonnance et télésuivi sans créer de dépendance circulaire.
 */
@Service
@RequiredArgsConstructor
public class CareAccessService {

    /** Consulter le dossier pour préparer une consultation (y compris en attente). */
    private static final Set<AppointmentStatus> VIEW_STATUSES =
            EnumSet.of(AppointmentStatus.PENDING, AppointmentStatus.ACCEPTED, AppointmentStatus.COMPLETED);

    /** Prescrire ou consulter les données de télésuivi : rendez-vous accepté ou terminé. */
    private static final Set<AppointmentStatus> TREAT_STATUSES =
            EnumSet.of(AppointmentStatus.ACCEPTED, AppointmentStatus.COMPLETED);

    private final AppointmentRepository appointmentRepository;

    @Transactional(readOnly = true)
    public void assertCanViewPatient(Long doctorId, Long patientId) {
        if (!appointmentRepository.existsByDoctorIdAndPatientIdAndStatusIn(doctorId, patientId, VIEW_STATUSES)) {
            throw new AccessDeniedException("Aucune relation de soin avec ce patient");
        }
    }

    @Transactional(readOnly = true)
    public void assertCanTreatPatient(Long doctorId, Long patientId) {
        if (!appointmentRepository.existsByDoctorIdAndPatientIdAndStatusIn(doctorId, patientId, TREAT_STATUSES)) {
            throw new AccessDeniedException("Un rendez-vous accepté avec ce patient est requis");
        }
    }

    @Transactional(readOnly = true)
    public List<Long> findPatientIdsOfDoctor(Long doctorId) {
        return appointmentRepository.findPatientIdsOfDoctor(doctorId, VIEW_STATUSES);
    }
}
