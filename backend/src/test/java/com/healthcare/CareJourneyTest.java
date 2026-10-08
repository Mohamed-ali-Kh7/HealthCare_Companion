package com.healthcare;

import com.fasterxml.jackson.databind.JsonNode;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;

import java.time.Instant;
import java.util.List;
import java.util.Map;

import static org.hamcrest.Matchers.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Parcours de soin complet sur les données de démo (patient, médecin, pharmacies). */
class CareJourneyTest extends AbstractIntegrationTest {

    @Test
    void doctorPrescribes_patientGetsMedicationAndFindsItNearby() throws Exception {
        String doctorToken = login("doctor@demo.tn", DEMO_PASSWORD);
        String patientToken = login("patient@demo.tn", DEMO_PASSWORD);

        // Le médecin voit ses patients (relation de soin issue des rendez-vous de démo)
        JsonNode patients = readJson(mockMvc.perform(get("/api/patients/my-patients")
                        .header(HttpHeaders.AUTHORIZATION, bearer(doctorToken)))
                .andExpect(status().isOk()).andReturn());
        long patientId = patients.get(0).get("id").asLong();

        // Médicament du référentiel
        JsonNode medicines = readJson(mockMvc.perform(get("/api/medicines").param("q", "paracétamol")
                        .header(HttpHeaders.AUTHORIZATION, bearer(doctorToken)))
                .andExpect(status().isOk()).andReturn());
        long medicineId = medicines.get("content").get(0).get("id").asLong();

        // Ordonnance
        Map<String, Object> prescription = Map.of(
                "patientId", patientId,
                "notes", "Repos",
                "items", List.of(Map.of(
                        "medicineId", medicineId,
                        "prescribedDosage", "1 comprimé",
                        "timesPerDay", 3,
                        "durationDays", 5,
                        "instructions", "Au milieu du repas")));
        mockMvc.perform(post("/api/prescriptions").header(HttpHeaders.AUTHORIZATION, bearer(doctorToken))
                        .contentType(MediaType.APPLICATION_JSON).content(json(prescription)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.items", hasSize(1)));

        // Le carnet du patient contient le traitement avec 3 rappels générés
        mockMvc.perform(get("/api/medications").header(HttpHeaders.AUTHORIZATION, bearer(patientToken)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[?(@.fromPrescription == true)].reminderTimes[*]", hasSize(3)));

        // Disponibilité dans les pharmacies proches du centre de Tunis
        mockMvc.perform(get("/api/pharmacies/availability")
                        .param("medicineId", String.valueOf(medicineId))
                        .param("lat", "36.8065").param("lng", "10.1815").param("radiusKm", "10")
                        .header(HttpHeaders.AUTHORIZATION, bearer(patientToken)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].pharmacy.distanceKm", lessThan(10.0)));
    }

    @Test
    void patientCannotPrescribe_andUnrelatedDoctorCannotReadSensors() throws Exception {
        String patientToken = login("patient@demo.tn", DEMO_PASSWORD);
        // Corps valide : la validation @Valid s'exécute avant @PreAuthorize, on teste donc bien le rôle
        Map<String, Object> prescription = Map.of("patientId", 1, "items", List.of(Map.of(
                "medicineId", 1, "prescribedDosage", "1 comprimé", "timesPerDay", 1, "durationDays", 1)));
        mockMvc.perform(post("/api/prescriptions").header(HttpHeaders.AUTHORIZATION, bearer(patientToken))
                        .contentType(MediaType.APPLICATION_JSON).content(json(prescription)))
                .andExpect(status().isForbidden());

        // Patient inexistant / non suivi → refus
        String doctorToken = login("doctor@demo.tn", DEMO_PASSWORD);
        mockMvc.perform(get("/api/sensor-data/patients/999999/summary").param("type", "STEPS")
                        .header(HttpHeaders.AUTHORIZATION, bearer(doctorToken)))
                .andExpect(status().isForbidden());
    }

    @Test
    void sensorBatch_isIdempotent() throws Exception {
        String patientToken = login("patient@demo.tn", DEMO_PASSWORD);
        Map<String, Object> batch = Map.of("readings", List.of(
                Map.of("type", "HEART_RATE", "value", 72, "recordedAt", Instant.now().minusSeconds(60).toString())));

        mockMvc.perform(post("/api/sensor-data").header(HttpHeaders.AUTHORIZATION, bearer(patientToken))
                        .contentType(MediaType.APPLICATION_JSON).content(json(batch)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.accepted").value(1));

        mockMvc.perform(post("/api/sensor-data").header(HttpHeaders.AUTHORIZATION, bearer(patientToken))
                        .contentType(MediaType.APPLICATION_JSON).content(json(batch)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.accepted").value(0))
                .andExpect(jsonPath("$.duplicates").value(1));
    }

    @Test
    void adminDashboard_aggregatesModules() throws Exception {
        String adminToken = login("admin@test.tn", "Admin12345");
        mockMvc.perform(get("/api/admin/dashboard").header(HttpHeaders.AUTHORIZATION, bearer(adminToken)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.usersByRole.PATIENT", greaterThanOrEqualTo(1)))
                .andExpect(jsonPath("$.pharmacies", greaterThanOrEqualTo(2)));
    }
}
