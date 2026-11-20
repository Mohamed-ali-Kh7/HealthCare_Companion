package com.healthcare;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.healthcare.assistant.AssistantProperties;
import com.healthcare.assistant.AssistantToolbox;
import com.healthcare.assistant.ClaudeAssistantAgent;
import com.healthcare.security.SecurityUser;
import com.healthcare.user.Role;
import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicInteger;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

/**
 * Boucle d'outils de l'assistant contre un faux serveur « API Claude » local (aucun appel réel, aucune clé) :
 * 1er tour → le modèle demande get_medical_history ; 2e tour → il répond. On vérifie les requêtes envoyées.
 */
class ClaudeAssistantAgentTest {

    private static final ObjectMapper JSON = new ObjectMapper();

    private HttpServer server;
    private final List<JsonNode> requests = Collections.synchronizedList(new ArrayList<>());
    private final AtomicInteger calls = new AtomicInteger();

    @BeforeEach
    void startFakeApi() throws IOException {
        server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/v1/messages", exchange -> {
            requests.add(JSON.readTree(exchange.getRequestBody()));
            String body = calls.getAndIncrement() == 0
                    ? """
                    {"id":"msg_1","type":"message","role":"assistant","model":"claude-opus-5-5",
                     "content":[{"type":"tool_use","id":"toolu_1","name":"get_medical_history","input":{}}],
                     "stop_reason":"tool_use","stop_sequence":null,
                     "usage":{"input_tokens":120,"output_tokens":20}}"""
                    : """
                    {"id":"msg_2","type":"message","role":"assistant","model":"claude-opus-5-5",
                     "content":[{"type":"text","text":"Évitez l'ibuprofène : vous êtes allergique à la pénicilline et suivi pour l'hypertension."}],
                     "stop_reason":"end_turn","stop_sequence":null,
                     "usage":{"input_tokens":300,"output_tokens":40}}""";
            byte[] bytes = body.getBytes(StandardCharsets.UTF_8);
            exchange.getResponseHeaders().add("Content-Type", "application/json");
            exchange.sendResponseHeaders(200, bytes.length);
            exchange.getResponseBody().write(bytes);
            exchange.close();
        });
        server.start();
    }

    @AfterEach
    void stop() {
        server.stop(0);
    }

    @Test
    void consulte_le_dossier_puis_repond() {
        AssistantToolbox toolbox = mock(AssistantToolbox.class);
        when(toolbox.medicalHistoryJson(any())).thenReturn("{\"patient\":{\"allergies\":\"Pénicilline\"}}");
        AssistantProperties props = new AssistantProperties("test-key", "claude-opus-5-5", 20, true,
                "http://127.0.0.1:" + server.getAddress().getPort());
        ClaudeAssistantAgent agent = new ClaudeAssistantAgent(props, toolbox, Clock.systemDefaultZone());
        SecurityUser patient = new SecurityUser(7L, "patient@demo.tn", "x", Role.PATIENT, true);

        Optional<String> reply = agent.reply(patient, List.of(), "Puis-je prendre de l'ibuprofène ?",
                Optional.empty(), new AssistantToolbox.Outcome());

        assertThat(reply).contains("Évitez l'ibuprofène : vous êtes allergique à la pénicilline et suivi pour l'hypertension.");
        verify(toolbox).medicalHistoryJson(patient); // patient du token, jamais un id choisi par le modèle
        assertThat(requests).hasSize(2);

        JsonNode first = requests.get(0);
        assertThat(first.get("model").asText()).isEqualTo("claude-opus-5-5");
        assertThat(first.at("/output_config/effort").asText()).isEqualTo("medium");
        assertThat(first.at("/system/0/cache_control/type").asText()).isEqualTo("ephemeral");
        assertThat(first.at("/system/1/text").asText()).startsWith("Date du jour");
        assertThat(first.get("fallbacks").asText()).isEqualTo("default");
        assertThat(first.get("tools")).hasSize(4);
        first.get("tools").forEach(t -> {
            assertThat(t.get("strict").asBoolean()).isTrue();
            assertThat(t.at("/input_schema/additionalProperties").asBoolean(true)).isFalse();
        });

        // 2e requête : réponse du modèle renvoyée telle quelle, puis le résultat de l'outil
        JsonNode messages = requests.get(1).get("messages");
        assertThat(messages).hasSize(3);
        assertThat(messages.at("/1/role").asText()).isEqualTo("assistant");
        assertThat(messages.at("/1/content/0/type").asText()).isEqualTo("tool_use");
        assertThat(messages.at("/2/content/0/type").asText()).isEqualTo("tool_result");
        assertThat(messages.at("/2/content/0/tool_use_id").asText()).isEqualTo("toolu_1");
        assertThat(messages.at("/2/content/0/content").asText()).contains("Pénicilline");
    }

    @Test
    void signale_le_filtre_de_securite_par_un_message_systeme() {
        AssistantToolbox toolbox = mock(AssistantToolbox.class);
        AssistantProperties props = new AssistantProperties("test-key", null, 0, false,
                "http://127.0.0.1:" + server.getAddress().getPort());
        calls.set(1); // le faux serveur répond directement par du texte
        ClaudeAssistantAgent agent = new ClaudeAssistantAgent(props, toolbox, Clock.systemDefaultZone());

        agent.reply(new SecurityUser(7L, "p@x.tn", "x", Role.PATIENT, true), List.of(),
                "J'ai mal à la poitrine", Optional.of("douleur thoracique"), new AssistantToolbox.Outcome());

        JsonNode messages = requests.get(0).get("messages");
        assertThat(messages.at("/0/role").asText()).isEqualTo("user");
        assertThat(messages.at("/1/role").asText()).isEqualTo("system");
        assertThat(messages.at("/1/content").toString()).contains("douleur thoracique");
        assertThat(requests.get(0).has("fallbacks")).isFalse();
    }
}
