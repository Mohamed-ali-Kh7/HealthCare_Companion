package com.healthcare;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.client.standard.StandardWebSocketClient;
import org.springframework.web.socket.handler.TextWebSocketHandler;

import java.util.Map;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.TimeUnit;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * Signalisation des appels sur un vrai serveur : sonnerie, décroché, relais WebRTC, raccroché.
 * Base H2 dédiée : ce contexte (port réel) ne doit pas recréer le schéma des autres tests.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT, properties =
        "spring.datasource.url=jdbc:h2:mem:calls;MODE=MySQL;DATABASE_TO_LOWER=TRUE;DB_CLOSE_DELAY=-1")
@ActiveProfiles("test")
class CallSignalingTest {

    @LocalServerPort
    private int port;

    @Autowired
    private TestRestTemplate rest;

    @Autowired
    private ObjectMapper objectMapper;

    /** Client WebSocket de test : chaque message reçu est mis en file. */
    private final class Client extends TextWebSocketHandler {
        final BlockingQueue<JsonNode> inbox = new LinkedBlockingQueue<>();
        WebSocketSession session;

        @Override
        protected void handleTextMessage(WebSocketSession s, TextMessage message) throws Exception {
            inbox.add(objectMapper.readTree(message.getPayload()));
        }

        /** Prochain message du type attendu (les autres, ex. "config", sont ignorés). */
        JsonNode next(String type) throws InterruptedException {
            long deadline = System.currentTimeMillis() + 5_000;
            while (System.currentTimeMillis() < deadline) {
                JsonNode m = inbox.poll(200, TimeUnit.MILLISECONDS);
                if (m != null && type.equals(m.path("type").asText())) {
                    return m;
                }
            }
            throw new AssertionError("Message '" + type + "' non reçu");
        }

        void send(Map<String, Object> payload) throws Exception {
            session.sendMessage(new TextMessage(objectMapper.writeValueAsString(payload)));
        }
    }

    private String login(String email) {
        JsonNode body = rest.postForObject("/api/auth/login",
                Map.of("email", email, "password", "Demo12345"), JsonNode.class);
        return body.get("accessToken").asText();
    }

    private long id(String token, String path) {
        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(token);
        return rest.exchange(path, HttpMethod.GET, new HttpEntity<>(headers), JsonNode.class)
                .getBody().get("id").asLong();
    }

    private Client connect(String token) throws Exception {
        Client client = new Client();
        client.session = new StandardWebSocketClient()
                .execute(client, "ws://localhost:" + port + "/ws/calls?token=" + token)
                .get(5, TimeUnit.SECONDS);
        return client;
    }

    @Test
    void connectionWithoutValidToken_isRefused() {
        assertThatThrownBy(() -> connect("invalide")).isInstanceOf(ExecutionException.class);
    }

    @Test
    void fullCall_ringAcceptRelayHangup() throws Exception {
        String patientToken = login("patient@demo.tn");
        String doctorToken = login("doctor@demo.tn");
        long doctorId = id(doctorToken, "/api/doctors/me");

        Client patient = connect(patientToken);
        Client doctor = connect(doctorToken);
        assertThat(patient.next("config").path("iceServers").isArray()).isTrue();

        // Le patient appelle son médecin en vidéo
        patient.send(Map.of("type", "invite", "contactId", doctorId, "video", true));
        JsonNode ringing = patient.next("ringing");
        String callId = ringing.path("callId").asText();
        JsonNode incoming = doctor.next("incoming");
        assertThat(incoming.path("callId").asText()).isEqualTo(callId);
        assertThat(incoming.path("video").asBoolean()).isTrue();
        assertThat(incoming.path("from").path("name").asText()).isNotBlank();

        // Le médecin décroche, l'offre WebRTC est relayée telle quelle
        doctor.send(Map.of("type", "accept", "callId", callId));
        patient.next("accepted");
        patient.send(Map.of("type", "signal", "callId", callId,
                "data", Map.of("type", "offer", "sdp", "v=0 test")));
        JsonNode relayed = doctor.next("signal");
        assertThat(relayed.path("data").path("sdp").asText()).isEqualTo("v=0 test");

        // Raccroché : l'autre participant est prévenu
        patient.send(Map.of("type", "hangup", "callId", callId));
        assertThat(doctor.next("ended").path("reason").asText()).isEqualTo("hangup");

        // L'appel est tracé dans la conversation, avec sa durée
        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(patientToken);
        JsonNode messages = rest.exchange("/api/messages/conversations/" + doctorId, HttpMethod.GET,
                new HttpEntity<>(headers), JsonNode.class).getBody();
        JsonNode last = messages.get(messages.size() - 1);
        assertThat(last.path("type").asText()).isEqualTo("CALL");
        assertThat(last.path("callVideo").asBoolean()).isTrue();
        assertThat(last.path("callDurationSeconds").isNumber()).isTrue();

        patient.session.close();
        doctor.session.close();
    }

    @Test
    void ambulanceCompany_callsPatientOfItsMission_inTheApp() throws Exception {
        String companyToken = login("ambulance@demo.tn");
        String patientToken = login("patient@demo.tn");
        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(companyToken);
        JsonNode missions = rest.exchange("/api/ambulance-requests/company", HttpMethod.GET,
                new HttpEntity<>(headers), JsonNode.class).getBody();
        long missionId = -1;
        for (JsonNode m : missions) {
            if ("REQUESTED".equals(m.path("mission").path("status").asText())) {
                missionId = m.get("id").asLong();
            }
        }
        assertThat(missionId).as("mission de démo à accepter").isPositive();

        Client company = connect(companyToken);
        Client patient = connect(patientToken);
        company.next("config");
        patient.next("config");

        // La société appelle le patient du transport : il voit le nom de la société
        company.send(Map.of("type", "invite", "missionId", missionId, "video", false));
        String callId = company.next("ringing").path("callId").asText();
        JsonNode incoming = patient.next("incoming");
        assertThat(incoming.path("from").path("name").asText()).isEqualTo("Ambulances Ennour (démo)");
        patient.send(Map.of("type", "accept", "callId", callId));
        company.next("accepted");
        company.send(Map.of("type", "hangup", "callId", callId));
        assertThat(patient.next("ended").path("reason").asText()).isEqualTo("hangup");

        // Une autre société ne peut pas appeler ce patient via cette mission
        Client other = connect(login("ambulance2@demo.tn"));
        other.send(Map.of("type", "invite", "missionId", missionId, "video", false));
        assertThat(other.next("ended").path("reason").asText()).isEqualTo("error");

        company.session.close();
        patient.session.close();
        other.session.close();
    }

    @Test
    void rejectedCall_isNotified() throws Exception {
        String patientToken = login("patient@demo.tn");
        String doctorToken = login("doctor@demo.tn");
        long patientId = id(patientToken, "/api/patients/me");

        Client patient = connect(patientToken);
        Client doctor = connect(doctorToken);

        // Cette fois le médecin appelle, en audio, et le patient refuse
        doctor.send(Map.of("type", "invite", "contactId", patientId, "video", false));
        String callId = patient.next("incoming").path("callId").asText();
        patient.send(Map.of("type", "reject", "callId", callId));
        assertThat(doctor.next("ended").path("reason").asText()).isEqualTo("rejected");

        patient.session.close();
        doctor.session.close();
    }
}
