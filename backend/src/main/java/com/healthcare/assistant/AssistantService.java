package com.healthcare.assistant;

import com.healthcare.assistant.dto.AssistantDtos.DoctorOption;
import com.healthcare.assistant.dto.AssistantDtos.MessageResponse;
import com.healthcare.assistant.dto.AssistantDtos.StatusResponse;
import com.healthcare.common.exception.BusinessRuleException;
import com.healthcare.doctor.Doctor;
import com.healthcare.doctor.DoctorService;
import com.healthcare.messaging.MessageType;
import com.healthcare.messaging.MessagingService;
import com.healthcare.patient.Patient;
import com.healthcare.patient.PatientService;
import com.healthcare.security.SecurityUser;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Optional;

/**
 * Assistant santé du patient : 24 h/24, avec IA si une clé est configurée, sinon en mode de secours.
 * Pas de transaction autour de l'appel à l'IA (plusieurs secondes) : chaque écriture est courte et indépendante.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AssistantService {

    private static final int HISTORY_PAGE = 50;

    private final AssistantMessageRepository repository;
    private final PatientService patientService;
    private final UrgencyDetector urgencyDetector;
    private final ClaudeAssistantAgent agent;
    private final FallbackResponder fallback;
    private final AssistantToolbox toolbox;
    private final AssistantProperties properties;
    private final DoctorService doctorService;
    private final MessagingService messagingService;
    private final Clock clock;

    public StatusResponse status() {
        return agent.available() ? new StatusResponse(true, "ai") : new StatusResponse(false, "offline");
    }

    @Transactional(readOnly = true)
    public List<MessageResponse> history(Long patientUserId) {
        Patient patient = patientService.getEntityByUserId(patientUserId);
        List<AssistantMessage> latest = new ArrayList<>(
                repository.findByPatientIdOrderByIdDesc(patient.getId(), PageRequest.of(0, HISTORY_PAGE)));
        Collections.reverse(latest);
        return latest.stream().map(MessageResponse::from).toList();
    }

    /** Message du patient → réponse de l'assistant (les deux sont enregistrés). */
    public MessageResponse ask(SecurityUser me, String message) {
        Patient patient = patientService.getEntityByUserId(me.id());
        List<AssistantMessage> previous = new ArrayList<>(repository.findByPatientIdOrderByIdDesc(
                patient.getId(), PageRequest.of(0, properties.historySize())));
        Collections.reverse(previous);
        repository.save(AssistantMessage.fromPatient(patient, message.trim()));

        // Filet de sécurité indépendant de l'IA
        Optional<String> urgency = urgencyDetector.detect(message);
        AssistantToolbox.Outcome outcome = new AssistantToolbox.Outcome();

        Optional<String> aiReply = agent.reply(me, previous, message.trim(), urgency, outcome);
        String reply;
        boolean ai = aiReply.isPresent();
        if (ai) {
            // La conduite à tenir en cas d'urgence figure toujours en fin de réponse
            reply = aiReply.get().contains("190") ? aiReply.get() : FallbackResponder.withEmergencyFooter(aiReply.get());
            // Un signe d'alerte repéré par les règles reste signalé, même si l'IA l'a jugé autrement
            urgency.ifPresent(reason -> toolbox.reportEmergency(reason, outcome));
        } else {
            reply = fallback.reply(me, message, urgency, outcome);
        }
        if (urgency.isPresent() || outcome.urgent) {
            log.warn("Assistant : situation urgente pour le patient #{} ({})", patient.getId(), outcome.urgencyReason);
        }
        AssistantMessage saved = repository.save(AssistantMessage.fromAssistant(patient, reply, outcome.urgent,
                outcome.urgencyReason, String.join(", ", outcome.forwardedTo), ai));
        return MessageResponse.from(saved);
    }

    public List<DoctorOption> myDoctors(SecurityUser me) {
        return toolbox.myDoctors(me);
    }

    /** Le patient laisse un message à son médecin ; une trace apparaît dans la conversation avec l'assistant. */
    public MessageResponse leaveMessageForDoctor(SecurityUser me, Long doctorId, String message) {
        Patient patient = patientService.getEntityByUserId(me.id());
        DoctorOption doctor = toolbox.leaveMessage(me, doctorId, message);
        AssistantMessage saved = repository.save(AssistantMessage.fromAssistant(patient,
                "Votre message a bien été transmis à " + doctor.name() + ". Il vous répondra dans la messagerie.",
                false, null, doctor.name(), false));
        return MessageResponse.from(saved);
    }

    /**
     * Transfert depuis la messagerie quand le médecin est indisponible : l'assistant reprend les derniers
     * messages du patient restés sans réponse et lui répond. Le transfert est visible dans la conversation.
     */
    public MessageResponse handoff(SecurityUser me, Long doctorId) {
        DoctorOption doctor = toolbox.myDoctors(me).stream().filter(d -> d.id().equals(doctorId)).findFirst()
                .orElseThrow(() -> new BusinessRuleException("NO_CARE_RELATION", "Ce médecin ne vous suit pas"));
        return ask(me, handoffText(me, doctor));
    }

    /**
     * Réponse automatique quand le patient écrit à un médecin absent : l'assistant répond aux messages restés
     * sans réponse, directement dans la conversation (et dans l'historique de l'assistant). Rien n'est envoyé
     * si le médecin est revenu entre-temps ou si ces messages ont déjà reçu une réponse.
     */
    public Optional<MessageResponse> autoReplyForAwayDoctor(SecurityUser me, Long doctorId) {
        Optional<DoctorOption> doctor = toolbox.myDoctors(me).stream().filter(d -> d.id().equals(doctorId)).findFirst();
        if (doctor.isEmpty() || !doctorService.getEntity(doctorId).isAwayOn(LocalDate.now(clock))) {
            return Optional.empty();
        }
        List<String> pending = pendingPatientMessages(me, doctorId);
        if (pending.isEmpty()) {
            return Optional.empty();
        }
        MessageResponse reply = ask(me, handoffText(me, doctor.get()));
        String intro = "🤖 Réponse automatique de l'assistant santé : " + doctor.get().name()
                + " est absent. Votre message est conservé, il le lira à son retour.\n\n";
        String body = reply.content().replaceFirst(
                "^Votre médecin est indisponible : je vous réponds en attendant son retour\\.\\s*", "");
        messagingService.postAssistantReply(me.id(), doctorId, intro + body);
        return Optional.of(reply);
    }

    /** Messages texte du patient après la dernière intervention du médecin ou de l'assistant (5 au plus). */
    private List<String> pendingPatientMessages(SecurityUser me, Long doctorId) {
        List<com.healthcare.messaging.dto.MessageResponse> recent = messagingService.getMessages(me, doctorId, null, null, 30);
        List<String> pending = new ArrayList<>();
        for (int i = recent.size() - 1; i >= 0 && recent.get(i).mine(); i--) {
            var m = recent.get(i);
            if (m.type() == MessageType.TEXT && m.content() != null && !m.content().isBlank()) {
                pending.add(0, m.content().trim());
            }
        }
        return pending.size() > 5 ? pending.subList(pending.size() - 5, pending.size()) : pending;
    }

    private String handoffText(SecurityUser me, DoctorOption doctor) {
        Long doctorId = doctor.id();
        Doctor entity = doctorService.getEntity(doctorId);
        List<String> pending = pendingPatientMessages(me, doctorId);

        StringBuilder text = new StringBuilder("(Transfert depuis la messagerie : ").append(doctor.name());
        if (entity.isAwayOn(LocalDate.now(clock))) {
            text.append(" est absent");
            if (entity.getAwayUntil() != null) {
                text.append(" jusqu'au ").append(entity.getAwayUntil().format(DateTimeFormatter.ofPattern("dd/MM/yyyy")));
            }
        } else {
            text.append(" n'est pas disponible pour le moment");
        }
        text.append(".)\n");
        if (pending.isEmpty()) {
            text.append("J'ai besoin d'aide en attendant son retour.");
        } else {
            text.append("Voici ce que je lui avais écrit :\n");
            pending.forEach(p -> text.append("« ").append(p).append(" »\n"));
            text.append("Pouvez-vous m'aider en attendant ?");
        }
        String message = text.toString();
        if (message.length() > 3800) {
            message = message.substring(0, 3800) + "…";
        }
        return message;
    }

    /** Nouvelle conversation : l'historique avec l'assistant est effacé (les messages aux médecins restent). */
    @Transactional
    public void clear(Long patientUserId) {
        repository.deleteByPatientId(patientService.getEntityByUserId(patientUserId).getId());
    }
}
