package com.healthcare.messaging;

import com.healthcare.appointment.CareAccessService;
import com.healthcare.common.exception.BusinessRuleException;
import com.healthcare.common.exception.ResourceNotFoundException;
import com.healthcare.doctor.Doctor;
import com.healthcare.doctor.DoctorService;
import com.healthcare.messaging.dto.ConversationResponse;
import com.healthcare.messaging.dto.MessageResponse;
import com.healthcare.messaging.dto.SendMessageRequest;
import com.healthcare.messaging.dto.UnreadCountResponse;
import com.healthcare.patient.Patient;
import com.healthcare.patient.PatientService;
import com.healthcare.security.SecurityUser;
import com.healthcare.user.Role;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.util.*;
import java.util.function.Function;
import java.util.stream.Collectors;
import java.util.stream.Stream;

/**
 * Messagerie patient - médecin. Une conversation par couple (patient, médecin), ouverte
 * uniquement s'il existe une relation de soin (rendez-vous en attente, accepté ou terminé),
 * selon la même règle que la consultation du dossier patient.
 */
@Service
@RequiredArgsConstructor
public class MessagingService {

    public static final int DEFAULT_PAGE_SIZE = 50;
    public static final int MAX_PAGE_SIZE = 100;

    /** Formats produits par les navigateurs (WebM/Ogg Opus) et les téléphones (AAC/M4A). */
    private static final Set<String> AUDIO_TYPES = Set.of(
            "audio/webm", "audio/ogg", "audio/mp4", "audio/m4a", "audio/x-m4a", "audio/aac", "audio/mpeg", "audio/wav");

    private final MessageRepository messageRepository;
    private final MessageAudioRepository audioRepository;
    private final PatientService patientService;
    private final DoctorService doctorService;
    private final CareAccessService careAccessService;
    private final MessagingProperties properties;
    private final Clock clock;
    private final org.springframework.context.ApplicationEventPublisher events;

    /** Contenu audio prêt à être servi. */
    public record AudioContent(String contentType, byte[] data) {
    }

    /** Les deux participants d'une conversation et le rôle de l'utilisateur connecté. */
    private record Participants(Patient patient, Doctor doctor, Role me) {
        Role other() {
            return me == Role.PATIENT ? Role.DOCTOR : Role.PATIENT;
        }
    }

    /** Tous les contacts de soin, y compris ceux sans message, triés par activité récente. */
    @Transactional(readOnly = true)
    public List<ConversationResponse> getConversations(SecurityUser me) {
        if (me.hasRole(Role.PATIENT)) {
            Patient patient = patientService.getEntityByUserId(me.id());
            List<Doctor> doctors = doctorService.getEntities(careAccessService.findDoctorIdsOfPatient(patient.getId()));
            Map<Long, Message> last = messageRepository.findLastMessagesOfPatient(patient.getId()).stream()
                    .collect(Collectors.toMap(m -> m.getDoctor().getId(), Function.identity()));
            Map<Long, Long> unread = toCountMap(messageRepository.countUnreadForPatient(patient.getId(), Role.DOCTOR));
            LocalDate today = LocalDate.now(clock);
            return sort(doctors.stream().map(d -> {
                boolean away = d.isAwayOn(today);
                return conversation(d.getId(), d.getFirstName(), d.getLastName(),
                        d.getSpeciality().getName(), last.get(d.getId()), unread.getOrDefault(d.getId(), 0L),
                        Role.PATIENT, away, away ? d.getAwayMessage() : null, away ? d.getAwayUntil() : null);
            }));
        }
        if (me.hasRole(Role.DOCTOR)) {
            Doctor doctor = doctorService.getEntityByUserId(me.id());
            List<Patient> patients = patientService.getEntities(careAccessService.findPatientIdsOfDoctor(doctor.getId()));
            Map<Long, Message> last = messageRepository.findLastMessagesOfDoctor(doctor.getId()).stream()
                    .collect(Collectors.toMap(m -> m.getPatient().getId(), Function.identity()));
            Map<Long, Long> unread = toCountMap(messageRepository.countUnreadForDoctor(doctor.getId(), Role.PATIENT));
            return sort(patients.stream().map(p -> conversation(p.getId(), p.getFirstName(), p.getLastName(),
                    null, last.get(p.getId()), unread.getOrDefault(p.getId(), 0L), Role.DOCTOR, false, null, null)));
        }
        throw new AccessDeniedException("Messagerie réservée aux patients et médecins");
    }

    /**
     * Sans curseur : les {@code size} derniers messages. {@code beforeId} : historique plus ancien.
     * {@code afterId} : nouveaux messages depuis le dernier reçu (rafraîchissement).
     * Toujours renvoyés dans l'ordre chronologique.
     */
    @Transactional(readOnly = true)
    public List<MessageResponse> getMessages(SecurityUser me, Long contactId, Long beforeId, Long afterId,
                                             Integer size) {
        Participants p = resolve(me, contactId);
        int limit = (size == null) ? DEFAULT_PAGE_SIZE : Math.max(1, Math.min(size, MAX_PAGE_SIZE));
        List<Message> messages;
        if (afterId != null) {
            messages = messageRepository.findAfter(p.patient().getId(), p.doctor().getId(), afterId,
                    PageRequest.of(0, limit));
        } else {
            messages = new ArrayList<>(messageRepository.findPage(p.patient().getId(), p.doctor().getId(),
                    beforeId, PageRequest.of(0, limit)));
            Collections.reverse(messages);
        }
        return messages.stream().map(m -> toResponse(m, p.me())).toList();
    }

    @Transactional
    public MessageResponse send(SecurityUser me, Long contactId, SendMessageRequest request) {
        return send(me, contactId, request, true);
    }

    /**
     * {@code autoReply} : si le patient écrit à un médecin absent, l'assistant lui répond automatiquement.
     * Faux pour les messages déposés par l'assistant lui-même (pas de réponse à soi-même).
     */
    @Transactional
    public MessageResponse send(SecurityUser me, Long contactId, SendMessageRequest request, boolean autoReply) {
        Participants p = resolve(me, contactId);
        Message saved = messageRepository.save(
                Message.text(p.patient(), p.doctor(), p.me(), request.content().trim()));
        if (autoReply && p.me() == Role.PATIENT && p.doctor().isAwayOn(LocalDate.now(clock))) {
            events.publishEvent(new PatientWroteToAwayDoctorEvent(me.id(), me.email(), p.doctor().getId()));
        }
        return toResponse(saved, p.me());
    }

    /** Réponse automatique de l'assistant dans la conversation patient ↔ médecin. */
    @Transactional
    public void postAssistantReply(Long patientUserId, Long doctorId, String content) {
        String text = content.length() > Message.MAX_LENGTH
                ? content.substring(0, Message.MAX_LENGTH - 1) + "…" : content;
        messageRepository.save(Message.assistant(patientService.getEntityByUserId(patientUserId),
                doctorService.getEntity(doctorId), text));
    }

    /** Message vocal : format audio reconnu, 5 Mo et {@code maxVoiceSeconds} au maximum. */
    @Transactional
    public MessageResponse sendVoice(SecurityUser me, Long contactId, MultipartFile file, int durationMs) {
        Participants p = resolve(me, contactId);
        if (file == null || file.isEmpty()) {
            throw new BusinessRuleException("VOICE_EMPTY", "Enregistrement vide");
        }
        if (file.getSize() > MessageAudio.MAX_BYTES) {
            throw new BusinessRuleException("FILE_TOO_LARGE", "Fichier trop volumineux");
        }
        String contentType = normalizeAudioType(file.getContentType());
        if (contentType == null) {
            throw new BusinessRuleException("VOICE_FORMAT", "Format audio non pris en charge");
        }
        if (durationMs <= 0 || durationMs > properties.maxVoiceSeconds() * 1000) {
            throw new BusinessRuleException("VOICE_DURATION",
                    "Durée invalide (maximum " + properties.maxVoiceSeconds() / 60 + " minutes)");
        }
        byte[] data;
        try {
            data = file.getBytes();
        } catch (IOException e) {
            throw new BusinessRuleException("VOICE_UNREADABLE", "Enregistrement illisible");
        }
        Message saved = messageRepository.save(Message.voice(p.patient(), p.doctor(), p.me(), durationMs));
        audioRepository.save(new MessageAudio(saved, contentType, data));
        return toResponse(saved, p.me());
    }

    /** Audio d'un message vocal : réservé aux deux participants (404 sinon, sans révéler l'existence). */
    @Transactional(readOnly = true)
    public AudioContent getAudio(SecurityUser me, Long messageId) {
        Message message = messageRepository.findById(messageId)
                .filter(m -> m.getType() == MessageType.VOICE && isParticipant(me, m))
                .orElseThrow(() -> new ResourceNotFoundException("Message", messageId));
        MessageAudio audio = audioRepository.findById(message.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Message", messageId));
        return new AudioContent(audio.getContentType(), audio.getData());
    }

    /**
     * Qui appeler, et comment l'appelant s'affiche chez l'appelé.
     *
     * @param calleeUserId        compte utilisateur à faire sonner
     * @param callerContactId     id de l'appelant vu par l'appelé (pour ouvrir la conversation)
     * @param callerName          nom affiché sur l'écran d'appel entrant
     * @param callerSubtitle      spécialité si l'appelant est médecin, sinon null
     * @param calleeName          nom de l'appelé (affiché chez l'appelant)
     * @param messageId           trace de l'appel dans la conversation (durée renseignée à la fin)
     */
    public record CallSetup(Long calleeUserId, Long callerContactId, String callerName, String callerSubtitle,
                            String calleeName, Long messageId) {
    }

    /**
     * Prépare un appel vers un contact de soin (même règle que la messagerie) et le trace dans la conversation.
     * La signalisation elle-même (sonnerie, WebRTC) est gérée par CallSignalingHandler.
     */
    @Transactional
    public CallSetup prepareCall(SecurityUser me, Long contactId, boolean video) {
        Participants p = resolve(me, contactId);
        Message saved = messageRepository.save(Message.call(p.patient(), p.doctor(), p.me(), video));
        Patient patient = p.patient();
        Doctor doctor = p.doctor();
        String patientName = patient.getFirstName() + " " + patient.getLastName();
        String doctorName = "Dr " + doctor.getFirstName() + " " + doctor.getLastName();
        if (p.me() == Role.PATIENT) {
            return new CallSetup(doctor.getUser().getId(), patient.getId(), patientName, null,
                    doctorName, saved.getId());
        }
        return new CallSetup(patient.getUser().getId(), doctor.getId(), doctorName,
                doctor.getSpeciality().getName(), patientName, saved.getId());
    }

    /** Fin d'un appel abouti : enregistre sa durée dans la conversation. */
    @Transactional
    public void recordCallDuration(Long messageId, int seconds) {
        messageRepository.findById(messageId).ifPresent(m -> m.recordCallDuration(Math.max(0, seconds)));
    }

    /** Marque comme lus les messages reçus de ce contact. Retourne le nombre de messages concernés. */
    @Transactional
    public int markAsRead(SecurityUser me, Long contactId) {
        Participants p = resolve(me, contactId);
        return messageRepository.markAsRead(p.patient().getId(), p.doctor().getId(), p.other(),
                Instant.now(clock));
    }

    /** Total des messages non lus (badge), limité aux contacts de soin actuels. */
    @Transactional(readOnly = true)
    public UnreadCountResponse getUnreadCount(SecurityUser me) {
        long total = getConversations(me).stream().mapToLong(ConversationResponse::unreadCount).sum();
        return new UnreadCountResponse(total);
    }

    /** Identifie les participants ; refuse si aucune relation de soin (403) ou contact inexistant (404). */
    private Participants resolve(SecurityUser me, Long contactId) {
        Participants p;
        if (me.hasRole(Role.PATIENT)) {
            p = new Participants(patientService.getEntityByUserId(me.id()),
                    doctorService.getEntity(contactId), Role.PATIENT);
        } else if (me.hasRole(Role.DOCTOR)) {
            p = new Participants(patientService.getEntity(contactId),
                    doctorService.getEntityByUserId(me.id()), Role.DOCTOR);
        } else {
            throw new AccessDeniedException("Messagerie réservée aux patients et médecins");
        }
        careAccessService.assertCanViewPatient(p.doctor().getId(), p.patient().getId());
        return p;
    }

    private boolean isParticipant(SecurityUser me, Message m) {
        if (me.hasRole(Role.PATIENT)) {
            return m.getPatient().getId().equals(patientService.getEntityByUserId(me.id()).getId());
        }
        if (me.hasRole(Role.DOCTOR)) {
            return m.getDoctor().getId().equals(doctorService.getEntityByUserId(me.id()).getId());
        }
        return false;
    }

    private static MessageResponse toResponse(Message m, Role viewer) {
        return MessageResponse.from(m, viewer);
    }

    /** "audio/webm;codecs=opus" → "audio/webm" si le format est accepté, sinon null. */
    private static String normalizeAudioType(String contentType) {
        if (contentType == null) {
            return null;
        }
        String base = contentType.split(";", 2)[0].trim().toLowerCase(Locale.ROOT);
        return AUDIO_TYPES.contains(base) ? base : null;
    }

    private static ConversationResponse conversation(Long id, String firstName, String lastName, String subtitle,
                                                     Message last, long unread, Role viewer,
                                                     boolean away, String awayMessage, LocalDate awayUntil) {
        return new ConversationResponse(id, firstName, lastName, subtitle,
                last == null ? null : last.getType(),
                last == null ? null : last.getContent(),
                last == null ? null : last.getCreatedAt(),
                last != null && last.getType() != MessageType.ASSISTANT && last.getSenderRole() == viewer,
                unread, away, awayMessage, awayUntil);
    }

    private static List<ConversationResponse> sort(Stream<ConversationResponse> stream) {
        return stream.sorted(Comparator
                        .comparing(ConversationResponse::lastMessageAt,
                                Comparator.nullsLast(Comparator.reverseOrder()))
                        .thenComparing(ConversationResponse::contactLastName, String.CASE_INSENSITIVE_ORDER)
                        .thenComparing(ConversationResponse::contactFirstName, String.CASE_INSENSITIVE_ORDER))
                .toList();
    }

    private static Map<Long, Long> toCountMap(List<Object[]> rows) {
        Map<Long, Long> map = new HashMap<>();
        for (Object[] row : rows) {
            map.put((Long) row[0], (Long) row[1]);
        }
        return map;
    }
}
