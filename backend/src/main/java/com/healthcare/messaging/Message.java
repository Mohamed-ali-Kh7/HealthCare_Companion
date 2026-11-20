package com.healthcare.messaging;

import com.healthcare.common.BaseEntity;
import com.healthcare.doctor.Doctor;
import com.healthcare.patient.Patient;
import com.healthcare.user.Role;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.Instant;

/**
 * Message échangé dans la conversation unique d'un couple (patient, médecin).
 * L'auteur est identifié par son rôle : la conversation n'a que deux participants.
 * Selon le type : texte ({@code content}), vocal (durée ; audio dans MessageAudio)
 * ou trace d'un appel audio/vidéo (durée, ou null si non abouti).
 */
@Entity
@Table(name = "messages", indexes = {
        @Index(name = "idx_message_conversation", columnList = "patient_id, doctor_id, id")
})
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Message extends BaseEntity {

    public static final int MAX_LENGTH = 2000;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "patient_id", nullable = false)
    private Patient patient;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "doctor_id", nullable = false)
    private Doctor doctor;

    @Enumerated(EnumType.STRING)
    @Column(name = "sender_role", nullable = false, length = 20)
    private Role senderRole;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 10)
    private MessageType type;

    /** Texte du message (type TEXT uniquement). */
    @Column(length = MAX_LENGTH)
    private String content;

    /** Durée du message vocal (type VOICE). */
    @Column(name = "audio_duration_ms")
    private Integer audioDurationMs;

    /** Appel vidéo (true) ou audio seul (false) (type CALL). */
    @Column(name = "call_video")
    private Boolean callVideo;

    /** Durée de l'appel une fois terminé ; null = appel non abouti (manqué, refusé, annulé) (type CALL). */
    @Column(name = "call_duration_seconds")
    private Integer callDurationSeconds;

    /** Date de lecture par le destinataire (null = non lu). */
    @Column(name = "read_at")
    private Instant readAt;

    private Message(Patient patient, Doctor doctor, Role senderRole, MessageType type) {
        this.patient = patient;
        this.doctor = doctor;
        this.senderRole = senderRole;
        this.type = type;
    }

    public static Message text(Patient patient, Doctor doctor, Role sender, String content) {
        Message m = new Message(patient, doctor, sender, MessageType.TEXT);
        m.content = content;
        return m;
    }

    public static Message voice(Patient patient, Doctor doctor, Role sender, int durationMs) {
        Message m = new Message(patient, doctor, sender, MessageType.VOICE);
        m.audioDurationMs = durationMs;
        return m;
    }

    /** Réponse de l'assistant, côté médecin pour apparaître comme non lue chez le patient. */
    public static Message assistant(Patient patient, Doctor doctor, String content) {
        Message m = new Message(patient, doctor, Role.DOCTOR, MessageType.ASSISTANT);
        m.content = content;
        return m;
    }

    /** Trace d'un appel dans la conversation ; la durée est renseignée à la fin de l'appel. */
    public static Message call(Patient patient, Doctor doctor, Role caller, boolean video) {
        Message m = new Message(patient, doctor, caller, MessageType.CALL);
        m.callVideo = video;
        return m;
    }

    public void recordCallDuration(int seconds) {
        this.callDurationSeconds = seconds;
    }
}
