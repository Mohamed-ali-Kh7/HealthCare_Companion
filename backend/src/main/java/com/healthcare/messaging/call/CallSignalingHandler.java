package com.healthcare.messaging.call;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.healthcare.ambulance.AmbulanceRequestService;
import com.healthcare.ambulance.AmbulanceRequestService.SamuContext;
import com.healthcare.ambulance.EmergencyRaisedEvent;
import com.healthcare.ambulance.TransportRequestedEvent;
import com.healthcare.appointment.CareAccessService;
import com.healthcare.doctor.DoctorAwayChangedEvent;
import com.healthcare.patient.PatientService;
import com.healthcare.order.OrderEvent;
import com.healthcare.user.Role;
import com.healthcare.messaging.MessagingProperties;
import com.healthcare.messaging.MessagingService;
import com.healthcare.messaging.MessagingService.CallSetup;
import com.healthcare.security.SecurityUser;
import jakarta.annotation.PreDestroy;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.ConcurrentWebSocketSessionDecorator;
import org.springframework.web.socket.handler.TextWebSocketHandler;

import java.io.IOException;
import java.time.Duration;
import java.time.Instant;
import java.util.*;
import java.util.concurrent.*;

/**
 * « Standard téléphonique » des appels audio/vidéo patient - médecin.
 * <p>
 * Le serveur fait sonner l'appelé, puis relaie les messages WebRTC (offre, réponse, candidats ICE)
 * entre les deux appareils. L'audio et la vidéo circulent directement d'un appareil à l'autre :
 * ils ne passent jamais par ce serveur.
 * <p>
 * Protocole (JSON, champ {@code type}) :
 * <pre>
 * client → serveur : invite {contactId, video} · accept {callId} · reject {callId}
 *                    hangup {callId} · signal {callId, data}
 * serveur → client : config {iceServers} · ringing {callId, video, calleeName}
 *                    incoming {callId, video, from {contactId, name, subtitle}}
 *                    accepted {callId} · signal {callId, data} · ended {callId, reason, message?}
 * </pre>
 * État en mémoire : convient à une instance unique du backend.
 */
@Slf4j
@Component
public class CallSignalingHandler extends TextWebSocketHandler {

    private static final int SEND_TIME_LIMIT_MS = 5_000;
    private static final int BUFFER_LIMIT_BYTES = 512 * 1024;

    private enum State { RINGING, ACTIVE }

    private static final class ActiveCall {
        final String id = UUID.randomUUID().toString();
        final long callerUserId;
        final long calleeUserId;
        final long messageId;
        final WebSocketSession callerSession;
        WebSocketSession calleeSession;
        State state = State.RINGING;
        Instant connectedAt;
        ScheduledFuture<?> ringTimeout;
        /** Message « appel entrant », renvoyé à chaque nouvelle fenêtre de l'appelé pendant la sonnerie. */
        Map<String, Object> incoming;
        /** Vrai dès qu'au moins une fenêtre de l'appelé a reçu l'appel. */
        boolean delivered;

        ActiveCall(long callerUserId, long calleeUserId, long messageId, WebSocketSession callerSession) {
            this.callerUserId = callerUserId;
            this.calleeUserId = calleeUserId;
            this.messageId = messageId;
            this.callerSession = callerSession;
        }

        WebSocketSession otherSession(WebSocketSession session) {
            return session.getId().equals(callerSession.getId()) ? calleeSession : callerSession;
        }

        boolean involves(WebSocketSession session) {
            return session.getId().equals(callerSession.getId())
                    || (calleeSession != null && session.getId().equals(calleeSession.getId()));
        }
    }

    /** Appel SAMU passé par un patient, montré en direct à ses médecins. */
    private static final class SamuCall {
        final long patientUserId;
        final String starterSessionId;
        final SamuContext context;
        final String number;
        final String label;
        Double latitude;
        Double longitude;
        Instant connectedAt;

        SamuCall(long patientUserId, String starterSessionId, SamuContext context, String number, String label) {
            this.patientUserId = patientUserId;
            this.starterSessionId = starterSessionId;
            this.context = context;
            this.number = number;
            this.label = label;
        }
    }

    private final MessagingService messagingService;
    private final AmbulanceRequestService ambulanceService;
    private final MessagingProperties properties;
    private final ObjectMapper objectMapper;
    private final ScheduledExecutorService scheduler = Executors.newSingleThreadScheduledExecutor(r -> {
        Thread t = new Thread(r, "call-ring-timeout");
        t.setDaemon(true);
        return t;
    });

    /** Toutes les modifications d'état se font sous ce verrou (volume faible : simplicité avant tout). */
    private final Object lock = new Object();
    private final Map<Long, Set<WebSocketSession>> sessionsByUser = new HashMap<>();
    private final Map<String, WebSocketSession> sessionsById = new HashMap<>();
    private final Map<String, ActiveCall> calls = new HashMap<>();
    private final Map<Long, ActiveCall> callByUser = new HashMap<>();
    /** Appels SAMU en cours, par utilisateur patient. */
    private final Map<Long, SamuCall> samuCalls = new HashMap<>();

    private final CareAccessService careAccessService;
    private final PatientService patientService;

    public CallSignalingHandler(MessagingService messagingService, AmbulanceRequestService ambulanceService,
                                CareAccessService careAccessService, PatientService patientService,
                                MessagingProperties properties, ObjectMapper objectMapper) {
        this.messagingService = messagingService;
        this.ambulanceService = ambulanceService;
        this.careAccessService = careAccessService;
        this.patientService = patientService;
        this.properties = properties;
        this.objectMapper = objectMapper;
    }

    @PreDestroy
    void shutdown() {
        scheduler.shutdownNow();
    }

    // --- Cycle de vie des connexions ---

    @Override
    public void afterConnectionEstablished(WebSocketSession raw) {
        WebSocketSession session =
                new ConcurrentWebSocketSessionDecorator(raw, SEND_TIME_LIMIT_MS, BUFFER_LIMIT_BYTES);
        synchronized (lock) {
            sessionsById.put(raw.getId(), session);
            sessionsByUser.computeIfAbsent(user(raw).id(), k -> new LinkedHashSet<>()).add(session);
            log.info("Appels : utilisateur {} ({}) connecté ({} fenêtre(s))", user(raw).id(), user(raw).role(),
                    sessionsByUser.get(user(raw).id()).size());
            send(session, Map.of("type", "config", "iceServers", properties.iceServers()));
            // Un appel sonne pour cet utilisateur (ex. page rechargée, réseau revenu) : on le lui remet
            ActiveCall pending = callByUser.get(user(raw).id());
            if (pending != null && pending.state == State.RINGING && pending.calleeUserId == user(raw).id()) {
                send(session, pending.incoming);
                pending.delivered = true;
            }
            // Un de ses patients est en ligne avec le SAMU : le médecin qui se connecte le voit aussi
            for (SamuCall samu : samuCalls.values()) {
                if (samu.context.doctorUserIds().contains(user(raw).id())) {
                    send(session, samuPayload(samu));
                }
            }
        }
    }

    @Override
    public void afterConnectionClosed(WebSocketSession raw, CloseStatus status) {
        log.info("Appels : utilisateur {} déconnecté ({})", user(raw).id(), status.getCode());
        synchronized (lock) {
            WebSocketSession session = sessionsById.remove(raw.getId());
            Set<WebSocketSession> userSessions = sessionsByUser.get(user(raw).id());
            if (userSessions != null && session != null) {
                userSessions.remove(session);
                if (userSessions.isEmpty()) {
                    sessionsByUser.remove(user(raw).id());
                }
            }
            ActiveCall call = callByUser.get(user(raw).id());
            if (call != null && session != null && call.involves(session)) {
                WebSocketSession other = call.otherSession(session);
                endCall(call, "disconnected", other == null ? List.of() : List.of(other));
            }
            SamuCall samu = samuCalls.get(user(raw).id());
            if (samu != null && samu.starterSessionId.equals(raw.getId())) {
                endSamu(samu);
            }
            // L'appelé qui ferme ou recharge sa fenêtre pendant la sonnerie : l'appel continue de sonner
            // (il lui sera remis à sa reconnexion), jusqu'au délai de sonnerie.
        }
    }

    @Override
    protected void handleTextMessage(WebSocketSession raw, TextMessage message) {
        JsonNode json;
        try {
            json = objectMapper.readTree(message.getPayload());
        } catch (IOException e) {
            return; // message illisible : ignoré
        }
        synchronized (lock) {
            WebSocketSession session = sessionsById.get(raw.getId());
            if (session == null) {
                return;
            }
            SecurityUser me = user(raw);
            switch (json.path("type").asText()) {
                case "invite" -> onInvite(session, me, json);
                case "accept" -> onAccept(session, me, json.path("callId").asText());
                case "reject" -> onReject(me, json.path("callId").asText());
                case "hangup" -> onHangup(session, me, json.path("callId").asText());
                case "signal" -> onSignal(session, me, json.path("callId").asText(), json.get("data"));
                case "samu_start" -> onSamuStart(session, raw.getId(), me, json);
                case "samu_update" -> onSamuUpdate(me, json);
                case "samu_end" -> {
                    SamuCall samu = samuCalls.get(me.id());
                    if (samu != null) {
                        endSamu(samu);
                    }
                }
                default -> log.debug("Message d'appel inconnu ignoré");
            }
        }
    }

    // --- Actions ---

    private void onInvite(WebSocketSession session, SecurityUser me, JsonNode json) {
        if (callByUser.containsKey(me.id())) {
            sendEnded(session, null, "error", "Un appel est déjà en cours");
            return;
        }
        long contactId = json.path("contactId").asLong(-1);
        long missionId = json.path("missionId").asLong(-1);
        boolean video = json.path("video").asBoolean(false);
        CallSetup setup;
        try {
            if (missionId > 0) {
                // Transport en ambulance conventionnée : patient ↔ société (pas de trace dans la messagerie)
                var t = ambulanceService.prepareTransportCall(me.id(), missionId);
                setup = new CallSetup(t.calleeUserId(), 0L, t.callerName(), t.callerSubtitle(), t.calleeName(), 0L);
            } else {
                setup = messagingService.prepareCall(me, contactId, video);
            }
        } catch (AccessDeniedException e) {
            sendEnded(session, null, "error", missionId > 0
                    ? "Appel impossible : aucun transport en cours avec ce contact"
                    : "Appel impossible : aucun rendez-vous avec ce contact");
            return;
        } catch (RuntimeException e) {
            log.debug("Appel refusé : {}", e.getMessage());
            sendEnded(session, null, "error", "Contact introuvable");
            return;
        }

        if (callByUser.containsKey(setup.calleeUserId())) {
            sendEnded(session, null, "busy", null);
            return;
        }
        Set<WebSocketSession> calleeSessions = sessionsByUser.getOrDefault(setup.calleeUserId(), Set.of());
        if (calleeSessions.isEmpty()) {
            // Comme une messagerie : on fait sonner quand même, l'appel sera remis si l'appelé se connecte
            log.info("Appels : {} appelle l'utilisateur {}, pas encore connecté : en attente", me.id(),
                    setup.calleeUserId());
        }

        ActiveCall call = new ActiveCall(me.id(), setup.calleeUserId(), setup.messageId(), session);
        calls.put(call.id, call);
        callByUser.put(call.callerUserId, call);
        callByUser.put(call.calleeUserId, call);

        send(session, Map.of("type", "ringing", "callId", call.id, "video", video,
                "calleeName", setup.calleeName()));
        Map<String, Object> from = new LinkedHashMap<>();
        from.put("contactId", setup.callerContactId());
        from.put("name", setup.callerName());
        from.put("subtitle", setup.callerSubtitle());
        call.incoming = Map.of("type", "incoming", "callId", call.id, "video", video, "from", from);
        calleeSessions.forEach(s -> send(s, call.incoming));
        call.delivered = !calleeSessions.isEmpty();

        call.ringTimeout = scheduler.schedule(() -> {
            synchronized (lock) {
                if (calls.get(call.id) == call && call.state == State.RINGING) {
                    // Jamais remis à l'appelé : il n'était pas connecté ; sinon : pas de réponse
                    endCall(call, call.delivered ? "timeout" : "unavailable", allSessionsOf(call));
                }
            }
        }, properties.ringTimeoutSeconds(), TimeUnit.SECONDS);
    }

    private void onAccept(WebSocketSession session, SecurityUser me, String callId) {
        ActiveCall call = calls.get(callId);
        if (call == null || call.state != State.RINGING || call.calleeUserId != me.id()) {
            sendEnded(session, callId, "error", "Cet appel n'est plus disponible");
            return;
        }
        call.state = State.ACTIVE;
        call.calleeSession = session;
        call.connectedAt = Instant.now();
        if (call.ringTimeout != null) {
            call.ringTimeout.cancel(false);
        }
        send(call.callerSession, Map.of("type", "accepted", "callId", call.id));
        // Les autres fenêtres de l'appelé arrêtent de sonner
        sessionsByUser.getOrDefault(me.id(), Set.of()).stream()
                .filter(s -> !s.getId().equals(session.getId()))
                .forEach(s -> sendEnded(s, call.id, "answered_elsewhere", null));
    }

    private void onReject(SecurityUser me, String callId) {
        ActiveCall call = calls.get(callId);
        if (call != null && call.state == State.RINGING && call.calleeUserId == me.id()) {
            endCall(call, "rejected", allSessionsOf(call));
        }
    }

    private void onHangup(WebSocketSession session, SecurityUser me, String callId) {
        ActiveCall call = calls.get(callId);
        if (call == null || (call.callerUserId != me.id() && call.calleeUserId != me.id())) {
            return;
        }
        if (call.state == State.RINGING) {
            // L'appelant annule avant que l'appelé ne décroche
            endCall(call, "cancelled", allSessionsOf(call));
        } else {
            WebSocketSession other = call.otherSession(session);
            endCall(call, "hangup", other == null ? List.of() : List.of(other));
        }
    }

    /** Relais WebRTC (offre, réponse, candidats ICE) vers l'autre participant uniquement. */
    private void onSignal(WebSocketSession session, SecurityUser me, String callId, JsonNode data) {
        ActiveCall call = calls.get(callId);
        if (call == null || call.state != State.ACTIVE || data == null || !call.involves(session)) {
            return;
        }
        WebSocketSession other = call.otherSession(session);
        if (other != null) {
            send(other, Map.of("type", "signal", "callId", call.id, "data", data));
        }
    }

    // --- Appel SAMU suivi en direct par les médecins ---
    // client patient → serveur : samu_start {number, label} · samu_update {connected?, latitude?, longitude?} · samu_end
    // serveur → patient : samu_ack {doctors, online}
    // serveur → médecins : samu_call {patientUserId, patient, number, label, latitude, longitude, connected,
    //                                 elapsedSeconds} · samu_ended {patientUserId, durationSeconds}

    private void onSamuStart(WebSocketSession session, String rawId, SecurityUser me, JsonNode json) {
        if (me.role() != Role.PATIENT) {
            return;
        }
        SamuContext context;
        try {
            context = ambulanceService.samuContext(me.id());
        } catch (RuntimeException e) {
            log.debug("Appel SAMU non relayé : {}", e.getMessage());
            return;
        }
        SamuCall previous = samuCalls.get(me.id());
        if (previous != null) {
            endSamu(previous);
        }
        SamuCall samu = new SamuCall(me.id(), rawId, context,
                json.path("number").asText("190"), json.path("label").asText("SAMU"));
        samuCalls.put(me.id(), samu);
        applySamuUpdate(samu, json);
        int online = broadcastSamu(samu, samuPayload(samu));
        log.warn("Patient {} appelle le {} ({}) : {} médecin(s), {} fenêtre(s) prévenue(s)", me.id(), samu.label,
                samu.number, context.doctorUserIds().size(), online);
        send(session, Map.of("type", "samu_ack", "doctors", context.doctorUserIds().size(), "online", online));
    }

    private void onSamuUpdate(SecurityUser me, JsonNode json) {
        SamuCall samu = samuCalls.get(me.id());
        if (samu != null) {
            applySamuUpdate(samu, json);
            broadcastSamu(samu, samuPayload(samu));
        }
    }

    private static void applySamuUpdate(SamuCall samu, JsonNode json) {
        if (json.path("connected").asBoolean(false) && samu.connectedAt == null) {
            samu.connectedAt = Instant.now();
        }
        if (json.path("latitude").isNumber() && json.path("longitude").isNumber()) {
            samu.latitude = json.path("latitude").asDouble();
            samu.longitude = json.path("longitude").asDouble();
        }
    }

    private void endSamu(SamuCall samu) {
        if (samuCalls.remove(samu.patientUserId, samu)) {
            long duration = samu.connectedAt == null ? 0 : Duration.between(samu.connectedAt, Instant.now()).toSeconds();
            broadcastSamu(samu, Map.of("type", "samu_ended", "patientUserId", samu.patientUserId,
                    "durationSeconds", duration));
        }
    }

    private Map<String, Object> samuPayload(SamuCall samu) {
        Map<String, Object> patient = new LinkedHashMap<>();
        patient.put("id", samu.context.patientId()); // contactId pour l'appel audio intégré
        patient.put("name", samu.context.patientName());
        patient.put("phone", samu.context.phone());
        patient.put("bloodGroup", samu.context.bloodGroup());
        patient.put("allergies", samu.context.allergies());
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("type", "samu_call");
        payload.put("patientUserId", samu.patientUserId);
        payload.put("patient", patient);
        payload.put("number", samu.number);
        payload.put("label", samu.label);
        payload.put("latitude", samu.latitude);
        payload.put("longitude", samu.longitude);
        payload.put("connected", samu.connectedAt != null);
        payload.put("elapsedSeconds",
                samu.connectedAt == null ? 0 : Duration.between(samu.connectedAt, Instant.now()).toSeconds());
        return payload;
    }

    /** Envoie à toutes les fenêtres ouvertes des médecins du patient ; renvoie le nombre de fenêtres atteintes. */
    private int broadcastSamu(SamuCall samu, Object payload) {
        int delivered = 0;
        for (Long doctorUserId : samu.context.doctorUserIds()) {
            for (WebSocketSession s : sessionsByUser.getOrDefault(doctorUserId, Set.of())) {
                send(s, payload);
                delivered++;
            }
        }
        return delivered;
    }

    // --- Alertes d'urgence ---

    /**
     * Pousse l'urgence d'un patient à toutes les fenêtres ouvertes de ses médecins (message {@code emergency}).
     * Après validation de la transaction : jamais d'alerte pour une demande finalement annulée.
     * Un médecin non connecté la retrouve dans son onglet Urgences.
     */
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
    public void onEmergency(EmergencyRaisedEvent event) {
        Map<String, Object> payload = Map.of("type", "emergency", "request", event.request());
        synchronized (lock) {
            int delivered = 0;
            for (Long userId : event.doctorUserIds()) {
                for (WebSocketSession session : sessionsByUser.getOrDefault(userId, Set.of())) {
                    send(session, payload);
                    delivered++;
                }
            }
            log.info("Urgence #{} : alerte envoyée à {} fenêtre(s) de {} médecin(s)",
                    event.request().id(), delivered, event.doctorUserIds().size());
        }
    }

    /** Médecin absent / de retour : ses patients connectés le voient aussitôt (message {@code doctor_status}). */
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
    public void onDoctorAwayChanged(DoctorAwayChangedEvent event) {
        List<Long> patientUserIds = patientService.getEntities(careAccessService.findPatientIdsOfDoctor(event.doctorId()))
                .stream().map(p -> p.getUser().getId()).toList();
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("type", "doctor_status");
        payload.put("doctorId", event.doctorId());
        payload.put("doctorName", event.doctorName());
        payload.put("away", event.away());
        payload.put("message", event.message());
        payload.put("until", event.until() == null ? null : event.until().toString());
        synchronized (lock) {
            patientUserIds.forEach(id -> sessionsByUser.getOrDefault(id, Set.of()).forEach(s -> send(s, payload)));
        }
        log.info("{} {} : {} patient(s) prévenu(s)", event.doctorName(), event.away() ? "absent" : "disponible",
                patientUserIds.size());
    }

    /** Transport programmé à valider : poussé au médecin choisi par le patient (message {@code transport_request}). */
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
    public void onTransportRequested(TransportRequestedEvent event) {
        Map<String, Object> payload = Map.of("type", "transport_request", "request", event.request());
        synchronized (lock) {
            Set<WebSocketSession> sessions = sessionsByUser.getOrDefault(event.doctorUserId(), Set.of());
            sessions.forEach(s -> send(s, payload));
            log.info("Transport #{} : médecin prévenu sur {} fenêtre(s)", event.request().id(), sessions.size());
        }
    }

    /** Mission d'ambulance conventionnée : patient, médecin et société (message {@code transport_mission}). */
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
    public void onTransportMission(com.healthcare.ambulance.TransportMissionEvent event) {
        Map<String, Object> payload = Map.of("type", "transport_mission", "request", event.request());
        synchronized (lock) {
            event.recipientUserIds().forEach(id ->
                    sessionsByUser.getOrDefault(id, Set.of()).forEach(s -> send(s, payload)));
        }
    }

    /** Commande de médicament créée ou mise à jour : poussée à l'autre partie (message {@code order_update}). */
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
    public void onOrderEvent(OrderEvent event) {
        Map<String, Object> payload = Map.of("type", "order_update", "order", event.order());
        synchronized (lock) {
            sessionsByUser.getOrDefault(event.recipientUserId(), Set.of()).forEach(s -> send(s, payload));
        }
    }

    /** Facture émise (→ patient) ou réglée (→ médecin) : message {@code invoice_update}. */
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
    public void onInvoiceEvent(com.healthcare.billing.InvoiceEvent event) {
        Map<String, Object> payload = Map.of("type", "invoice_update", "kind", event.kind(),
                "invoice", event.invoice());
        synchronized (lock) {
            sessionsByUser.getOrDefault(event.recipientUserId(), Set.of()).forEach(s -> send(s, payload));
        }
    }

    // --- Utilitaires ---

    private void endCall(ActiveCall call, String reason, Collection<WebSocketSession> notify) {
        if (calls.remove(call.id) == null) {
            return;
        }
        callByUser.remove(call.callerUserId, call);
        callByUser.remove(call.calleeUserId, call);
        if (call.ringTimeout != null) {
            call.ringTimeout.cancel(false);
        }
        // messageId 0 : appel de transport, sans trace dans une conversation
        if (call.state == State.ACTIVE && call.connectedAt != null && call.messageId > 0) {
            int seconds = (int) Duration.between(call.connectedAt, Instant.now()).toSeconds();
            try {
                messagingService.recordCallDuration(call.messageId, seconds);
            } catch (RuntimeException e) {
                log.warn("Durée d'appel non enregistrée : {}", e.getMessage());
            }
        }
        notify.forEach(s -> sendEnded(s, call.id, reason, null));
    }

    /** Appelant + toutes les fenêtres ouvertes de l'appelé (pendant la sonnerie). */
    private List<WebSocketSession> allSessionsOf(ActiveCall call) {
        List<WebSocketSession> sessions = new ArrayList<>();
        sessions.add(call.callerSession);
        sessions.addAll(sessionsByUser.getOrDefault(call.calleeUserId, Set.of()));
        return sessions;
    }

    private void sendEnded(WebSocketSession session, String callId, String reason, String message) {
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("type", "ended");
        payload.put("callId", callId);
        payload.put("reason", reason);
        if (message != null) {
            payload.put("message", message);
        }
        send(session, payload);
    }

    private void send(WebSocketSession session, Object payload) {
        if (!session.isOpen()) {
            return;
        }
        try {
            session.sendMessage(new TextMessage(objectMapper.writeValueAsString(payload)));
        } catch (IOException | IllegalStateException e) {
            log.debug("Envoi impossible sur la session {} : {}", session.getId(), e.getMessage());
        }
    }

    private static SecurityUser user(WebSocketSession session) {
        return (SecurityUser) session.getAttributes().get(CallHandshakeInterceptor.USER_ATTR);
    }
}
