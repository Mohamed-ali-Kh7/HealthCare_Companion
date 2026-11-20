package com.healthcare.assistant.dto;

import com.healthcare.assistant.AssistantMessage;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.Instant;
import java.util.List;

/** DTO de l'assistant santé. */
public final class AssistantDtos {

    private AssistantDtos() {
    }

    public record AskRequest(@NotBlank @Size(max = 2000) String message) {
    }

    /** Message laissé par le patient à un de ses médecins, avec ses propres mots. */
    public record DoctorMessageRequest(@NotNull Long doctorId, @NotBlank @Size(max = 1800) String message) {
    }

    public record HandoffRequest(@NotNull Long doctorId) {
    }

    public record MessageResponse(Long id, AssistantMessage.Role role, String content, boolean urgent,
                                  String urgencyReason, List<String> forwardedTo, boolean aiGenerated,
                                  Instant createdAt) {
        public static MessageResponse from(AssistantMessage m) {
            List<String> forwarded = m.getForwardedTo() == null || m.getForwardedTo().isBlank()
                    ? List.of() : List.of(m.getForwardedTo().split(", "));
            return new MessageResponse(m.getId(), m.getRole(), m.getContent(), m.isUrgent(), m.getUrgencyReason(),
                    forwarded, m.isAiGenerated(), m.getCreatedAt());
        }
    }

    /** État de l'assistant : avec IA (Claude) ou en mode de secours. */
    public record StatusResponse(boolean aiEnabled, String mode) {
    }

    public record DoctorOption(Long id, String name, String speciality) {
    }
}
