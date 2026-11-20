package com.healthcare.assistant;

import com.healthcare.common.BaseEntity;
import com.healthcare.patient.Patient;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

/** Un message de la conversation entre un patient et l'assistant santé. */
@Entity
@Table(name = "assistant_messages", indexes = @Index(name = "idx_assistant_patient", columnList = "patient_id, id"))
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class AssistantMessage extends BaseEntity {

    public enum Role { USER, ASSISTANT }

    public static final int MAX_LENGTH = 4000;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "patient_id", nullable = false)
    private Patient patient;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 10)
    private Role role;

    @Column(nullable = false, length = MAX_LENGTH)
    private String content;

    /** Situation jugée urgente : l'application affiche l'appel au 190 et l'alerte des médecins. */
    private boolean urgent;

    @Column(name = "urgency_reason", length = 200)
    private String urgencyReason;

    /** Médecins à qui la demande a été transmise (noms, séparés par des virgules). */
    @Column(name = "forwarded_to", length = 300)
    private String forwardedTo;

    /** Réponse produite par l'IA (true) ou par le mode de secours sans IA (false). */
    @Column(name = "ai_generated")
    private boolean aiGenerated;

    private AssistantMessage(Patient patient, Role role, String content) {
        this.patient = patient;
        this.role = role;
        this.content = content.length() > MAX_LENGTH ? content.substring(0, MAX_LENGTH) : content;
    }

    public static AssistantMessage fromPatient(Patient patient, String content) {
        return new AssistantMessage(patient, Role.USER, content);
    }

    public static AssistantMessage fromAssistant(Patient patient, String content, boolean urgent, String urgencyReason,
                                                 String forwardedTo, boolean aiGenerated) {
        AssistantMessage m = new AssistantMessage(patient, Role.ASSISTANT, content);
        m.urgent = urgent;
        m.urgencyReason = urgencyReason;
        m.forwardedTo = forwardedTo;
        m.aiGenerated = aiGenerated;
        return m;
    }
}
