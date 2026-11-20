package com.healthcare.ambulance;

import com.healthcare.common.BaseEntity;
import com.healthcare.common.exception.BusinessRuleException;
import com.healthcare.common.exception.ConflictException;
import com.healthcare.doctor.Doctor;
import com.healthcare.patient.Patient;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import com.healthcare.transport.AmbulanceCompany;
import com.healthcare.transport.AmbulanceVehicle;

import java.time.Instant;
import java.time.LocalDateTime;

/**
 * Demande d'ambulance. Les transitions de statut sont encapsulées ici (pas de setStatus public),
 * voir {@link AmbulanceRequestStatus}.
 *
 * {@code doctor} : médecin qui valide (transport programmé) ou qui prend en charge (urgence).
 */
@Entity
@Table(name = "ambulance_requests", indexes = {
        @Index(name = "idx_ambulance_patient", columnList = "patient_id"),
        @Index(name = "idx_ambulance_doctor", columnList = "doctor_id"),
        @Index(name = "idx_ambulance_type_status", columnList = "type, status")
})
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class AmbulanceRequest extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "patient_id", nullable = false)
    private Patient patient;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "doctor_id")
    private Doctor doctor;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private AmbulanceRequestType type;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private AmbulanceRequestStatus status;

    private Double latitude;

    private Double longitude;

    @Column(length = 255)
    private String address;

    @Column(length = 500)
    private String reason;

    /** Heure locale de prise en charge souhaitée (transport programmé uniquement). */
    @Column(name = "scheduled_at")
    private LocalDateTime scheduledAt;

    /** Motif de refus ou consigne du médecin. */
    @Column(name = "doctor_note", length = 500)
    private String doctorNote;

    // --- Exécution par une société d'ambulance conventionnée (transport programmé validé)

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "company_id")
    private AmbulanceCompany company;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "vehicle_id")
    private AmbulanceVehicle vehicle;

    @Enumerated(EnumType.STRING)
    @Column(name = "mission_status", length = 20)
    private MissionStatus missionStatus;

    /** Motif de refus ou message de la société au patient. */
    @Column(name = "company_note", length = 500)
    private String companyNote;

    @Column(name = "mission_updated_at")
    private Instant missionUpdatedAt;

    private AmbulanceRequest(Patient patient, Doctor doctor, AmbulanceRequestType type, AmbulanceRequestStatus status,
                             Double latitude, Double longitude, String address, String reason,
                             LocalDateTime scheduledAt) {
        this.patient = patient;
        this.doctor = doctor;
        this.type = type;
        this.status = status;
        this.latitude = latitude;
        this.longitude = longitude;
        this.address = address;
        this.reason = reason;
        this.scheduledAt = scheduledAt;
    }

    public static AmbulanceRequest emergency(Patient patient, Double latitude, Double longitude,
                                             String address, String reason) {
        return new AmbulanceRequest(patient, null, AmbulanceRequestType.EMERGENCY,
                AmbulanceRequestStatus.DISPATCHED, latitude, longitude, address, reason, null);
    }

    public static AmbulanceRequest scheduled(Patient patient, Doctor doctor, Double latitude, Double longitude,
                                             String address, String reason, LocalDateTime scheduledAt) {
        return new AmbulanceRequest(patient, doctor, AmbulanceRequestType.SCHEDULED,
                AmbulanceRequestStatus.PENDING, latitude, longitude, address, reason, scheduledAt);
    }

    public boolean isEmergency() {
        return type == AmbulanceRequestType.EMERGENCY;
    }

    // ---------------------------------------------------------------- Urgence

    /** Le premier médecin qui répond devient le médecin référent de l'urgence. */
    public void takeCharge(Doctor by, String note) {
        requireType(AmbulanceRequestType.EMERGENCY);
        requireStatus(AmbulanceRequestStatus.DISPATCHED);
        if (doctor != null && !doctor.getId().equals(by.getId())) {
            throw new ConflictException("EMERGENCY_ALREADY_HANDLED", "Cette urgence est déjà prise en charge par un autre médecin");
        }
        doctor = by;
        if (note != null) {
            doctorNote = note;
        }
    }

    // ---------------------------------------------------------------- Transport programmé

    public void approve(String note) {
        requireType(AmbulanceRequestType.SCHEDULED);
        requireStatus(AmbulanceRequestStatus.PENDING);
        status = AmbulanceRequestStatus.APPROVED;
        doctorNote = note;
    }

    public void reject(String note) {
        requireType(AmbulanceRequestType.SCHEDULED);
        requireStatus(AmbulanceRequestStatus.PENDING);
        status = AmbulanceRequestStatus.REJECTED;
        doctorNote = note;
    }

    /** Demande restée sans réponse après l'heure prévue. */
    public void expire() {
        requireStatus(AmbulanceRequestStatus.PENDING);
        status = AmbulanceRequestStatus.REJECTED;
        doctorNote = "Demande expirée : aucune validation avant l'heure prévue";
    }

    // ---------------------------------------------------------------- Ambulance conventionnée

    /** Le patient confie le transport validé à une société (ou à une autre après un refus). */
    public void assignCompany(AmbulanceCompany chosen, Instant now) {
        requireType(AmbulanceRequestType.SCHEDULED);
        requireStatus(AmbulanceRequestStatus.APPROVED);
        if (missionStatus != null && missionStatus != MissionStatus.REFUSED && missionStatus != MissionStatus.REQUESTED) {
            throw new BusinessRuleException("MISSION_ALREADY_ACCEPTED",
                    "Une société a déjà accepté ce transport : annulez-le d'abord");
        }
        company = chosen;
        vehicle = null;
        companyNote = null;
        missionStatus = MissionStatus.REQUESTED;
        missionUpdatedAt = now;
    }

    public void acceptMission(AmbulanceVehicle assigned, String note, Instant now) {
        requireMission(MissionStatus.REQUESTED);
        vehicle = assigned;
        companyNote = note;
        missionStatus = MissionStatus.ACCEPTED;
        missionUpdatedAt = now;
    }

    public void refuseMission(String note, Instant now) {
        requireMission(MissionStatus.REQUESTED);
        companyNote = note;
        missionStatus = MissionStatus.REFUSED;
        missionUpdatedAt = now;
    }

    /** Étape suivante du trajet ; à l'arrivée, la demande est clôturée. */
    public MissionStatus advanceMission(Instant now) {
        requireActiveTransport();
        MissionStatus next = missionStatus == null ? null : missionStatus.next();
        if (next == null) {
            throw new BusinessRuleException("INVALID_STATUS_TRANSITION",
                    "Aucune étape suivante pour ce transport (" + missionStatus + ")");
        }
        missionStatus = next;
        missionUpdatedAt = now;
        if (next == MissionStatus.ARRIVED) {
            status = AmbulanceRequestStatus.CLOSED;
        }
        return next;
    }

    /** Une société est concernée par le transport : demande en attente de sa réponse, acceptée ou en cours. */
    public boolean involvesCompany() {
        return missionStatus != null && missionStatus != MissionStatus.REFUSED;
    }

    private void requireMission(MissionStatus expected) {
        requireActiveTransport();
        if (missionStatus != expected) {
            throw new BusinessRuleException("INVALID_STATUS_TRANSITION",
                    "Opération impossible : la mission est " + missionStatus);
        }
    }

    /** La société ne peut plus agir sur un transport annulé par le patient ou déjà clôturé. */
    private void requireActiveTransport() {
        if (status != AmbulanceRequestStatus.APPROVED) {
            throw new BusinessRuleException("INVALID_STATUS_TRANSITION", switch (status) {
                case CANCELLED -> "Ce transport a été annulé par le patient";
                case CLOSED -> "Ce transport est terminé";
                default -> "Ce transport n'est plus actif (" + status + ")";
            });
        }
    }

    // ---------------------------------------------------------------- Commun

    public void cancel(LocalDateTime now) {
        if (missionStatus != null && missionStatus.started()) {
            throw new BusinessRuleException("MISSION_STARTED", "L'ambulance est déjà partie : appelez la société");
        }
        boolean cancellable = switch (type) {
            case EMERGENCY -> status == AmbulanceRequestStatus.DISPATCHED;
            case SCHEDULED -> (status == AmbulanceRequestStatus.PENDING || status == AmbulanceRequestStatus.APPROVED)
                    && scheduledAt.isAfter(now);
        };
        if (!cancellable) {
            throw new BusinessRuleException("INVALID_STATUS_TRANSITION",
                    "Cette demande ne peut plus être annulée (" + status + ")");
        }
        status = AmbulanceRequestStatus.CANCELLED;
    }

    /**
     * Fin de la prise en charge : urgence résolue ou transport effectué.
     * Un transport dont la société a affecté un véhicule est clôturé par la société elle-même à l'arrivée :
     * le clôturer avant bloquerait le suivi du trajet et sa facturation.
     */
    public void close() {
        if (status != AmbulanceRequestStatus.DISPATCHED && status != AmbulanceRequestStatus.APPROVED) {
            throw new BusinessRuleException("INVALID_STATUS_TRANSITION",
                    "Seule une demande en cours peut être clôturée (" + status + ")");
        }
        if (missionStatus != null && missionStatus.inProgress()) {
            throw new BusinessRuleException("MISSION_IN_PROGRESS",
                    "Ce transport est pris en charge par une société d'ambulance : elle le clôture à l'arrivée");
        }
        status = AmbulanceRequestStatus.CLOSED;
    }

    private void requireType(AmbulanceRequestType expected) {
        if (type != expected) {
            throw new BusinessRuleException("INVALID_REQUEST_TYPE", "Opération impossible pour ce type de demande");
        }
    }

    private void requireStatus(AmbulanceRequestStatus expected) {
        if (status != expected) {
            throw new BusinessRuleException("INVALID_STATUS_TRANSITION",
                    "Opération impossible : la demande est " + status);
        }
    }
}
