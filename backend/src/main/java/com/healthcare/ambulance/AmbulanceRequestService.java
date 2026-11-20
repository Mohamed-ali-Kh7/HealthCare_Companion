package com.healthcare.ambulance;

import com.healthcare.ambulance.dto.AmbulanceRequestResponse;
import com.healthcare.ambulance.dto.CreateAmbulanceRequest;
import com.healthcare.appointment.CareAccessService;
import com.healthcare.common.exception.BusinessRuleException;
import com.healthcare.common.exception.ConflictException;
import com.healthcare.common.exception.ResourceNotFoundException;
import com.healthcare.doctor.Doctor;
import com.healthcare.doctor.DoctorService;
import com.healthcare.patient.Patient;
import com.healthcare.patient.PatientService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import com.healthcare.transport.AmbulanceCompany;
import com.healthcare.transport.AmbulanceVehicle;
import com.healthcare.transport.TransportCompanyService;

import java.time.Instant;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * Demandes d'ambulance.
 * - Urgence : enregistrée immédiatement (DISPATCHED), sans attendre de validation ;
 *   les médecins du patient sont informés et l'un d'eux peut la prendre en charge.
 * - Transport programmé : soumis à la validation du médecin traitant choisi par le patient.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AmbulanceRequestService {

    /** Horizon de réservation d'un transport programmé, comme pour les rendez-vous. */
    private static final int MAX_DAYS_AHEAD = 90;

    private final AmbulanceRequestRepository repository;
    private final PatientService patientService;
    private final DoctorService doctorService;
    private final CareAccessService careAccessService;
    private final TransportCompanyService transportCompanyService;
    private final Clock clock;
    private final ApplicationEventPublisher events;

    // ---------------------------------------------------------------- Patient

    @Transactional
    public AmbulanceRequestResponse create(Long patientUserId, CreateAmbulanceRequest request) {
        Patient patient = patientService.getEntityByUserId(patientUserId);
        String address = trimToNull(request.address());
        String reason = trimToNull(request.reason());

        AmbulanceRequest created = switch (request.type()) {
            case EMERGENCY -> {
                if (repository.existsByPatientIdAndTypeAndStatus(patient.getId(),
                        AmbulanceRequestType.EMERGENCY, AmbulanceRequestStatus.DISPATCHED)) {
                    throw new ConflictException("EMERGENCY_ALREADY_ACTIVE",
                            "Une urgence est déjà en cours. Appelez le SAMU (190) si la situation s'aggrave");
                }
                yield AmbulanceRequest.emergency(patient, request.latitude(), request.longitude(), address, reason);
            }
            case SCHEDULED -> {
                LocalDateTime scheduledAt = validateSchedule(request.scheduledAt());
                if (address == null) {
                    throw new BusinessRuleException("ADDRESS_REQUIRED", "L'adresse de prise en charge est obligatoire");
                }
                if (request.doctorId() == null) {
                    throw new BusinessRuleException("DOCTOR_REQUIRED", "Choisissez le médecin qui validera le transport");
                }
                Doctor doctor = doctorService.getEntity(request.doctorId());
                if (!careAccessService.canTreatPatient(doctor.getId(), patient.getId())) {
                    throw new BusinessRuleException("NO_CARE_RELATION",
                            "Seul un médecin qui vous suit (rendez-vous accepté) peut valider ce transport");
                }
                yield AmbulanceRequest.scheduled(patient, doctor, request.latitude(), request.longitude(),
                        address, reason, scheduledAt);
            }
        };

        AmbulanceRequest saved = repository.save(created);
        AmbulanceRequestResponse response = AmbulanceRequestResponse.from(saved);
        if (saved.isEmergency()) {
            log.warn("URGENCE ambulance #{} déclenchée par le patient #{}", saved.getId(), patient.getId());
            // Alerte temps réel des médecins qui suivent le patient (envoyée après validation de la transaction)
            List<Long> doctorUserIds = careAccessService.findDoctorIdsOfPatient(patient.getId()).stream()
                    .map(doctorId -> doctorService.getEntity(doctorId).getUser().getId())
                    .toList();
            events.publishEvent(new EmergencyRaisedEvent(response, doctorUserIds));
        } else {
            // Le médecin choisi est prévenu tout de suite qu'un transport attend sa validation
            events.publishEvent(new TransportRequestedEvent(response, saved.getDoctor().getUser().getId()));
        }
        return response;
    }

    @Transactional(readOnly = true)
    public List<AmbulanceRequestResponse> getMine(Long patientUserId) {
        Patient patient = patientService.getEntityByUserId(patientUserId);
        return repository.findByPatientIdOrderByCreatedAtDesc(patient.getId()).stream()
                .map(AmbulanceRequestResponse::from)
                .toList();
    }

    @Transactional
    public AmbulanceRequestResponse cancel(Long patientUserId, Long requestId) {
        AmbulanceRequest request = findOwnedByPatient(patientUserId, requestId);
        request.cancel(LocalDateTime.now(clock));
        return afterEnd(request);
    }

    @Transactional
    public AmbulanceRequestResponse closeByPatient(Long patientUserId, Long requestId) {
        AmbulanceRequest request = findOwnedByPatient(patientUserId, requestId);
        request.close();
        return afterEnd(request);
    }

    /**
     * Annulation ou clôture : si une société était concernée (demande en attente de sa réponse ou acceptée),
     * elle est prévenue en direct, avec le médecin, pour retirer la mission de ses tâches.
     */
    private AmbulanceRequestResponse afterEnd(AmbulanceRequest request) {
        return request.involvesCompany() ? publishMission(request) : AmbulanceRequestResponse.from(request);
    }

    // ---------------------------------------------------------------- Médecin

    @Transactional(readOnly = true)
    public List<AmbulanceRequestResponse> getForDoctor(Long doctorUserId) {
        Doctor doctor = doctorService.getEntityByUserId(doctorUserId);
        List<Long> patientIds = careAccessService.findPatientIdsOfDoctor(doctor.getId());
        // Liste "in" jamais vide (certaines bases refusent "in ()")
        return repository.findForDoctor(doctor.getId(), patientIds.isEmpty() ? List.of(-1L) : patientIds).stream()
                .map(AmbulanceRequestResponse::from)
                .toList();
    }

    @Transactional
    public AmbulanceRequestResponse takeCharge(Long doctorUserId, Long requestId, String note) {
        Doctor doctor = doctorService.getEntityByUserId(doctorUserId);
        AmbulanceRequest request = findDetailed(requestId);
        careAccessService.assertCanViewPatient(doctor.getId(), request.getPatient().getId());
        request.takeCharge(doctor, trimToNull(note));
        return AmbulanceRequestResponse.from(request);
    }

    @Transactional
    public AmbulanceRequestResponse approve(Long doctorUserId, Long requestId, String note) {
        AmbulanceRequest request = findAssignedToDoctor(doctorUserId, requestId);
        if (!request.getScheduledAt().isAfter(LocalDateTime.now(clock))) {
            throw new BusinessRuleException("REQUEST_EXPIRED", "L'heure prévue du transport est déjà passée");
        }
        request.approve(trimToNull(note));
        return AmbulanceRequestResponse.from(request);
    }

    @Transactional
    public AmbulanceRequestResponse reject(Long doctorUserId, Long requestId, String note) {
        AmbulanceRequest request = findAssignedToDoctor(doctorUserId, requestId);
        request.reject(trimToNull(note));
        return AmbulanceRequestResponse.from(request);
    }

    @Transactional
    public AmbulanceRequestResponse closeByDoctor(Long doctorUserId, Long requestId) {
        AmbulanceRequest request = findAssignedToDoctor(doctorUserId, requestId);
        request.close();
        return afterEnd(request);
    }

    // ---------------------------------------------------------------- Ambulance conventionnée

    /** Patient : confie son transport validé à une société conventionnée, qui est prévenue en direct. */
    @Transactional
    public AmbulanceRequestResponse chooseCompany(Long patientUserId, Long requestId, Long companyId) {
        AmbulanceRequest request = findOwnedByPatient(patientUserId, requestId);
        AmbulanceCompany company = transportCompanyService.getEntity(companyId);
        if (!company.getUser().isEnabled() || !company.isAcceptingRequests()) {
            throw new BusinessRuleException("COMPANY_UNAVAILABLE", "Cette société n'accepte pas de demandes pour le moment");
        }
        if (!request.getScheduledAt().isAfter(LocalDateTime.now(clock))) {
            throw new BusinessRuleException("REQUEST_EXPIRED", "L'heure prévue du transport est déjà passée");
        }
        request.assignCompany(company, Instant.now(clock));
        return publishMission(request);
    }

    /** Société : ses missions (à accepter, planifiées, en cours, terminées). */
    @Transactional(readOnly = true)
    public List<AmbulanceRequestResponse> getForCompany(Long companyUserId) {
        AmbulanceCompany company = transportCompanyService.getEntityByUserId(companyUserId);
        return repository.findByCompanyIdOrderByScheduledAtAsc(company.getId()).stream()
                .map(AmbulanceRequestResponse::from)
                .toList();
    }

    @Transactional
    public AmbulanceRequestResponse acceptMission(Long companyUserId, Long requestId, Long vehicleId, String note) {
        AmbulanceRequest request = findAssignedToCompany(companyUserId, requestId);
        AmbulanceVehicle vehicle = transportCompanyService.getVehicleForMission(companyUserId, vehicleId);
        request.acceptMission(vehicle, trimToNull(note), Instant.now(clock));
        return publishMission(request);
    }

    @Transactional
    public AmbulanceRequestResponse refuseMission(Long companyUserId, Long requestId, String note) {
        AmbulanceRequest request = findAssignedToCompany(companyUserId, requestId);
        request.refuseMission(trimToNull(note), Instant.now(clock));
        return publishMission(request);
    }

    /** Étape suivante : en route → sur place → transport en cours → arrivé (la demande est clôturée). */
    @Transactional
    public AmbulanceRequestResponse advanceMission(Long companyUserId, Long requestId) {
        AmbulanceRequest request = findAssignedToCompany(companyUserId, requestId);
        request.advanceMission(Instant.now(clock));
        return publishMission(request);
    }

    /** Pour la facturation : transport terminé, réalisé par la société connectée. */
    @Transactional(readOnly = true)
    public AmbulanceRequest getArrivedEntityForCompany(Long companyUserId, Long requestId) {
        AmbulanceRequest request = findAssignedToCompany(companyUserId, requestId);
        if (request.getMissionStatus() != MissionStatus.ARRIVED) {
            throw new BusinessRuleException("MISSION_NOT_FINISHED", "Seul un transport terminé peut être facturé");
        }
        return request;
    }

    /** Pour la facturation : transports terminés de la société, les plus récents d'abord. */
    @Transactional(readOnly = true)
    public List<AmbulanceRequest> findArrivedEntitiesForCompany(Long companyId) {
        List<AmbulanceRequest> list = new ArrayList<>(repository.findByCompanyIdOrderByScheduledAtAsc(companyId).stream()
                .filter(r -> r.getMissionStatus() == MissionStatus.ARRIVED)
                .toList());
        Collections.reverse(list);
        return list;
    }

    /** Appel audio/vidéo dans l'application entre le patient et la société chargée de son transport. */
    public record TransportCallSetup(Long calleeUserId, String callerName, String callerSubtitle, String calleeName) {
    }

    /**
     * Prépare un appel lié à une mission : seuls le patient et la société concernée peuvent s'appeler, tant que le
     * transport n'est pas terminé ni refusé. Sinon : AccessDeniedException.
     */
    @Transactional(readOnly = true)
    public TransportCallSetup prepareTransportCall(Long callerUserId, Long requestId) {
        AmbulanceRequest r = findDetailed(requestId);
        MissionStatus m = r.getMissionStatus();
        if (r.getCompany() == null || m == null || m == MissionStatus.REFUSED || m == MissionStatus.ARRIVED
                || r.getStatus() != AmbulanceRequestStatus.APPROVED) {
            throw new AccessDeniedException("Aucun transport en cours avec ce contact");
        }
        Patient p = r.getPatient();
        AmbulanceCompany c = r.getCompany();
        String patientName = p.getFirstName() + " " + p.getLastName();
        String when = r.getScheduledAt() == null ? "" : " du "
                + r.getScheduledAt().format(java.time.format.DateTimeFormatter.ofPattern("dd/MM HH:mm"));
        if (callerUserId.equals(p.getUser().getId())) {
            return new TransportCallSetup(c.getUser().getId(), patientName, "Patient · transport" + when, c.getName());
        }
        if (callerUserId.equals(c.getUser().getId())) {
            return new TransportCallSetup(p.getUser().getId(), c.getName(), "Ambulance conventionnée · transport" + when,
                    patientName);
        }
        throw new AccessDeniedException("Ce transport ne vous concerne pas");
    }

    private AmbulanceRequest findAssignedToCompany(Long companyUserId, Long requestId) {
        AmbulanceCompany company = transportCompanyService.getEntityByUserId(companyUserId);
        AmbulanceRequest request = findDetailed(requestId);
        if (request.getCompany() == null || !request.getCompany().getId().equals(company.getId())) {
            throw new ResourceNotFoundException("Demande d'ambulance", requestId);
        }
        return request;
    }

    /** Patient, médecin et société sont prévenus en direct (après validation de la transaction). */
    private AmbulanceRequestResponse publishMission(AmbulanceRequest request) {
        AmbulanceRequestResponse response = AmbulanceRequestResponse.from(request);
        List<Long> recipients = new ArrayList<>();
        recipients.add(request.getPatient().getUser().getId());
        if (request.getDoctor() != null) {
            recipients.add(request.getDoctor().getUser().getId());
        }
        if (request.getCompany() != null) {
            recipients.add(request.getCompany().getUser().getId());
        }
        events.publishEvent(new TransportMissionEvent(response, recipients));
        return response;
    }

    // ---------------------------------------------------------------- Tâche planifiée

    /** Les transports programmés restés sans réponse après leur heure sont refusés automatiquement. */
    @Scheduled(fixedDelayString = "${app.ambulance.expiry-check-ms:900000}", initialDelay = 60_000)
    @Transactional
    public int expireOverdueRequests() {
        List<AmbulanceRequest> overdue = repository.findByStatusAndScheduledAtBefore(
                AmbulanceRequestStatus.PENDING, LocalDateTime.now(clock));
        overdue.forEach(AmbulanceRequest::expire);
        if (!overdue.isEmpty()) {
            log.info("{} demande(s) de transport expirée(s)", overdue.size());
        }
        return overdue.size();
    }

    // ---------------------------------------------------------------- Appel SAMU suivi en direct

    /** Ce que les médecins voient pendant que leur patient appelle le SAMU. */
    public record SamuContext(Long patientId, String patientName, String phone, String bloodGroup,
                              String allergies, List<Long> doctorUserIds) {
    }

    @Transactional(readOnly = true)
    public SamuContext samuContext(Long patientUserId) {
        Patient patient = patientService.getEntityByUserId(patientUserId);
        List<Long> doctorUserIds = careAccessService.findDoctorIdsOfPatient(patient.getId()).stream()
                .map(doctorId -> doctorService.getEntity(doctorId).getUser().getId())
                .toList();
        return new SamuContext(patient.getId(), patient.getFirstName() + " " + patient.getLastName(), patient.getPhone(),
                patient.getBloodGroup(), patient.getAllergies(), doctorUserIds);
    }

    // ---------------------------------------------------------------- Statistiques

    @Transactional(readOnly = true)
    public long countForPatient(Long patientId) {
        return repository.countByPatientId(patientId);
    }

    /** Transports qui attendent la validation de ce médecin. */
    @Transactional(readOnly = true)
    public long countPendingForDoctor(Long doctorId) {
        return repository.countByDoctorIdAndStatus(doctorId, AmbulanceRequestStatus.PENDING);
    }

    /** Urgences en cours chez les patients suivis. */
    @Transactional(readOnly = true)
    public long countActiveEmergencies(List<Long> patientIds) {
        return patientIds.isEmpty() ? 0 : repository.countByTypeAndStatusAndPatientIdIn(
                AmbulanceRequestType.EMERGENCY, AmbulanceRequestStatus.DISPATCHED, patientIds);
    }

    // ---------------------------------------------------------------- Interne

    private LocalDateTime validateSchedule(LocalDateTime scheduledAt) {
        if (scheduledAt == null) {
            throw new BusinessRuleException("SCHEDULE_REQUIRED", "La date et l'heure du transport sont obligatoires");
        }
        LocalDateTime now = LocalDateTime.now(clock);
        LocalDateTime value = scheduledAt.withSecond(0).withNano(0);
        if (!value.isAfter(now)) {
            throw new BusinessRuleException("SCHEDULE_IN_PAST", "La date du transport doit être dans le futur");
        }
        if (value.isAfter(now.plusDays(MAX_DAYS_AHEAD))) {
            throw new BusinessRuleException("SCHEDULE_TOO_FAR", "Un transport se réserve au plus 3 mois à l'avance");
        }
        return value;
    }

    private AmbulanceRequest findDetailed(Long id) {
        return repository.findWithDetailsById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Demande d'ambulance", id));
    }

    private AmbulanceRequest findOwnedByPatient(Long patientUserId, Long requestId) {
        Patient patient = patientService.getEntityByUserId(patientUserId);
        AmbulanceRequest request = findDetailed(requestId);
        if (!request.getPatient().getId().equals(patient.getId())) {
            throw new ResourceNotFoundException("Demande d'ambulance", requestId); // ne révèle pas son existence
        }
        return request;
    }

    /** Transport adressé à ce médecin, ou urgence qu'il a prise en charge. */
    private AmbulanceRequest findAssignedToDoctor(Long doctorUserId, Long requestId) {
        Doctor doctor = doctorService.getEntityByUserId(doctorUserId);
        AmbulanceRequest request = findDetailed(requestId);
        if (request.getDoctor() == null || !request.getDoctor().getId().equals(doctor.getId())) {
            throw new ResourceNotFoundException("Demande d'ambulance", requestId);
        }
        return request;
    }

    private static String trimToNull(String value) {
        return (value == null || value.isBlank()) ? null : value.trim();
    }
}
