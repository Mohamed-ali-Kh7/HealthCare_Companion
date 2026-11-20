package com.healthcare;

import org.junit.jupiter.api.Test;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;

import java.util.Map;

import static org.hamcrest.Matchers.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/** Messagerie patient - médecin : texte, vocal, lecture, et règle de la relation de soin. */
class MessagingTest extends AbstractIntegrationTest {

    private static final String BASE = "/api/messages";

    private long id(String token, String path) throws Exception {
        return readJson(mockMvc.perform(get(path).header(HttpHeaders.AUTHORIZATION, bearer(token)))
                .andExpect(status().isOk()).andReturn()).get("id").asLong();
    }

    @Test
    void textConversation_withUnreadCountAndReadReceipt() throws Exception {
        String patientToken = login("patient@demo.tn", DEMO_PASSWORD);
        String doctorToken = login("doctor@demo.tn", DEMO_PASSWORD);
        long doctorId = id(doctorToken, "/api/doctors/me");
        long patientId = id(patientToken, "/api/patients/me");

        // Le médecin de démo (rendez-vous accepté) fait partie des contacts du patient, même sans message
        mockMvc.perform(get(BASE + "/conversations").header(HttpHeaders.AUTHORIZATION, bearer(patientToken)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[*].contactId", hasItem((int) doctorId)));

        mockMvc.perform(post(BASE + "/conversations/" + doctorId).header(HttpHeaders.AUTHORIZATION, bearer(patientToken))
                        .contentType(MediaType.APPLICATION_JSON).content(json(Map.of("content", "  Bonjour docteur  "))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.type").value("TEXT"))
                .andExpect(jsonPath("$.content").value("Bonjour docteur"))
                .andExpect(jsonPath("$.mine").value(true));

        // Côté médecin : message reçu, non lu
        mockMvc.perform(get(BASE + "/unread-count").header(HttpHeaders.AUTHORIZATION, bearer(doctorToken)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.unreadCount", greaterThanOrEqualTo(1)));
        mockMvc.perform(get(BASE + "/conversations/" + patientId).header(HttpHeaders.AUTHORIZATION, bearer(doctorToken)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[-1].content").value("Bonjour docteur"))
                .andExpect(jsonPath("$[-1].mine").value(false))
                .andExpect(jsonPath("$[-1].readAt").doesNotExist());

        mockMvc.perform(put(BASE + "/conversations/" + patientId + "/read")
                        .header(HttpHeaders.AUTHORIZATION, bearer(doctorToken)))
                .andExpect(status().isNoContent());
        mockMvc.perform(get(BASE + "/unread-count").header(HttpHeaders.AUTHORIZATION, bearer(doctorToken)))
                .andExpect(jsonPath("$.unreadCount").value(0));

        // Le patient voit l'accusé de lecture sur son message
        mockMvc.perform(get(BASE + "/conversations/" + doctorId).header(HttpHeaders.AUTHORIZATION, bearer(patientToken)))
                .andExpect(jsonPath("$[-1].readAt").exists());
    }

    @Test
    void voiceMessage_isStoredAndOnlyServedToParticipants() throws Exception {
        String patientToken = login("patient@demo.tn", DEMO_PASSWORD);
        String doctorToken = login("doctor@demo.tn", DEMO_PASSWORD);
        long doctorId = id(doctorToken, "/api/doctors/me");
        byte[] audio = {1, 2, 3, 4, 5, 6, 7, 8};

        long messageId = readJson(mockMvc.perform(multipart(BASE + "/conversations/" + doctorId + "/voice")
                        .file(new MockMultipartFile("file", "note.webm", "audio/webm;codecs=opus", audio))
                        .param("durationMs", "3500")
                        .header(HttpHeaders.AUTHORIZATION, bearer(patientToken)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.type").value("VOICE"))
                .andExpect(jsonPath("$.audioDurationMs").value(3500))
                .andReturn()).get("id").asLong();

        mockMvc.perform(get(BASE + "/" + messageId + "/audio").header(HttpHeaders.AUTHORIZATION, bearer(doctorToken)))
                .andExpect(status().isOk())
                .andExpect(content().contentType("audio/webm"))
                .andExpect(content().bytes(audio));

        // Un pharmacien n'a pas accès à la messagerie
        String pharmacistToken = login("pharmacist@demo.tn", DEMO_PASSWORD);
        mockMvc.perform(get(BASE + "/" + messageId + "/audio").header(HttpHeaders.AUTHORIZATION, bearer(pharmacistToken)))
                .andExpect(status().isForbidden());

        // Formats et durées refusés
        mockMvc.perform(multipart(BASE + "/conversations/" + doctorId + "/voice")
                        .file(new MockMultipartFile("file", "x.exe", "application/octet-stream", audio))
                        .param("durationMs", "3500")
                        .header(HttpHeaders.AUTHORIZATION, bearer(patientToken)))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.code").value("VOICE_FORMAT"));
        mockMvc.perform(multipart(BASE + "/conversations/" + doctorId + "/voice")
                        .file(new MockMultipartFile("file", "long.webm", "audio/webm", audio))
                        .param("durationMs", "999999")
                        .header(HttpHeaders.AUTHORIZATION, bearer(patientToken)))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.code").value("VOICE_DURATION"));
    }

    @Test
    void noCareRelation_noConversation() throws Exception {
        String doctorToken = login("doctor@demo.tn", DEMO_PASSWORD);
        // Patient inexistant
        mockMvc.perform(post(BASE + "/conversations/999999").header(HttpHeaders.AUTHORIZATION, bearer(doctorToken))
                        .contentType(MediaType.APPLICATION_JSON).content(json(Map.of("content", "Bonjour"))))
                .andExpect(status().isNotFound());

        // Message vide refusé
        String patientToken = login("patient@demo.tn", DEMO_PASSWORD);
        long doctorId = id(doctorToken, "/api/doctors/me");
        mockMvc.perform(post(BASE + "/conversations/" + doctorId).header(HttpHeaders.AUTHORIZATION, bearer(patientToken))
                        .contentType(MediaType.APPLICATION_JSON).content(json(Map.of("content", "   "))))
                .andExpect(status().isBadRequest());
    }
}
