package com.healthcare;

import com.fasterxml.jackson.databind.JsonNode;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;

import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;
import java.util.Map;

import static org.hamcrest.Matchers.hasItem;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Demandes d'ambulance : urgence sans validation, transport programmé validé par le médecin. */
class AmbulanceRequestTest extends AbstractIntegrationTest {

    private static final String BASE = "/api/ambulance-requests";

    @Test
    void emergency_isDispatchedImmediately_andDoctorCanTakeCharge() throws Exception {
        String patientToken = login("patient@demo.tn", DEMO_PASSWORD);
        String doctorToken = login("doctor@demo.tn", DEMO_PASSWORD);

        // Aucune validation : la demande part directement
        JsonNode created = readJson(mockMvc.perform(post(BASE).header(HttpHeaders.AUTHORIZATION, bearer(patientToken))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("type", "EMERGENCY", "latitude", 36.8065, "longitude", 10.1815,
                                "reason", "Douleur thoracique"))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.status").value("DISPATCHED"))
                .andExpect(jsonPath("$.doctor").doesNotExist())
                .andReturn());
        long id = created.get("id").asLong();

        // Une seule urgence active à la fois
        mockMvc.perform(post(BASE).header(HttpHeaders.AUTHORIZATION, bearer(patientToken))
                        .contentType(MediaType.APPLICATION_JSON).content(json(Map.of("type", "EMERGENCY"))))
                .andExpect(status().isConflict());

        // Le médecin du patient la voit, avec les informations utiles aux secours
        mockMvc.perform(get(BASE + "/doctor").header(HttpHeaders.AUTHORIZATION, bearer(doctorToken)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[*].id", hasItem((int) id)));

        mockMvc.perform(put(BASE + "/" + id + "/take-charge").header(HttpHeaders.AUTHORIZATION, bearer(doctorToken))
                        .contentType(MediaType.APPLICATION_JSON).content(json(Map.of("note", "J'appelle le patient"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.doctor.id").exists())
                .andExpect(jsonPath("$.doctorNote").value("J'appelle le patient"));

        // Résolue par le médecin référent → une nouvelle urgence redevient possible
        mockMvc.perform(put(BASE + "/" + id + "/close").header(HttpHeaders.AUTHORIZATION, bearer(doctorToken)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("CLOSED"));
    }

    @Test
    void scheduledTransport_requiresValidationByTreatingDoctor() throws Exception {
        String patientToken = login("patient@demo.tn", DEMO_PASSWORD);
        String doctorToken = login("doctor@demo.tn", DEMO_PASSWORD);
        long doctorId = readJson(mockMvc.perform(get("/api/doctors/me")
                        .header(HttpHeaders.AUTHORIZATION, bearer(doctorToken)))
                .andExpect(status().isOk()).andReturn()).get("id").asLong();
        String tomorrow = LocalDateTime.now().plusDays(1).truncatedTo(ChronoUnit.MINUTES).toString();

        // Date passée refusée
        mockMvc.perform(post(BASE).header(HttpHeaders.AUTHORIZATION, bearer(patientToken))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("type", "SCHEDULED", "doctorId", doctorId, "address", "Tunis",
                                "scheduledAt", LocalDateTime.now().minusDays(1).truncatedTo(ChronoUnit.MINUTES).toString()))))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.code").value("SCHEDULE_IN_PAST"));

        // Adresse obligatoire
        mockMvc.perform(post(BASE).header(HttpHeaders.AUTHORIZATION, bearer(patientToken))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("type", "SCHEDULED", "doctorId", doctorId, "scheduledAt", tomorrow))))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.code").value("ADDRESS_REQUIRED"));

        long id = readJson(mockMvc.perform(post(BASE).header(HttpHeaders.AUTHORIZATION, bearer(patientToken))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("type", "SCHEDULED", "doctorId", doctorId,
                                "address", "12 rue de Marseille, Tunis", "reason", "Séance de dialyse",
                                "scheduledAt", tomorrow))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.status").value("PENDING"))
                .andReturn()).get("id").asLong();

        // Le patient ne peut pas valider sa propre demande
        mockMvc.perform(put(BASE + "/" + id + "/approve").header(HttpHeaders.AUTHORIZATION, bearer(patientToken)))
                .andExpect(status().isForbidden());

        mockMvc.perform(put(BASE + "/" + id + "/approve").header(HttpHeaders.AUTHORIZATION, bearer(doctorToken))
                        .contentType(MediaType.APPLICATION_JSON).content(json(Map.of("note", "Prévoir un fauteuil"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("APPROVED"));

        // Déjà validée : un refus n'est plus possible
        mockMvc.perform(put(BASE + "/" + id + "/reject").header(HttpHeaders.AUTHORIZATION, bearer(doctorToken)))
                .andExpect(status().isUnprocessableEntity());

        mockMvc.perform(put(BASE + "/" + id + "/cancel").header(HttpHeaders.AUTHORIZATION, bearer(patientToken)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("CANCELLED"));
    }

    @Test
    void scheduledTransport_unknownDoctor_isRejected() throws Exception {
        String patientToken = login("patient@demo.tn", DEMO_PASSWORD);
        mockMvc.perform(post(BASE).header(HttpHeaders.AUTHORIZATION, bearer(patientToken))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("type", "SCHEDULED", "doctorId", 999999, "address", "Tunis",
                                "scheduledAt", LocalDateTime.now().plusDays(2).truncatedTo(ChronoUnit.MINUTES).toString()))))
                .andExpect(status().isNotFound());
    }
}
