package com.healthcare;

import org.junit.jupiter.api.Test;
import org.springframework.http.HttpHeaders;

import static org.hamcrest.Matchers.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Statistiques personnelles, calculées sur les données de démo (rendez-vous accepté, 7 jours de capteurs). */
class StatsTest extends AbstractIntegrationTest {

    @Test
    void patientStats_aggregateAppointmentsTreatmentsAndActivity() throws Exception {
        String patientToken = login("patient@demo.tn", DEMO_PASSWORD);
        mockMvc.perform(get("/api/stats/patient").header(HttpHeaders.AUTHORIZATION, bearer(patientToken)))
                .andExpect(status().isOk())
                // Tous les statuts sont présents, même à 0
                .andExpect(jsonPath("$.appointmentsByStatus.*", hasSize(5)))
                .andExpect(jsonPath("$.doctorsConsulted", greaterThanOrEqualTo(1)))
                .andExpect(jsonPath("$.activity.stepsPerDay", hasSize(7)))
                .andExpect(jsonPath("$.activity.daysWithSteps", greaterThanOrEqualTo(1)))
                .andExpect(jsonPath("$.activity.averageDailySteps", greaterThan(0)));
    }

    @Test
    void doctorStats_aggregatePatientsPlanningAndPrescriptions() throws Exception {
        String doctorToken = login("doctor@demo.tn", DEMO_PASSWORD);
        mockMvc.perform(get("/api/stats/doctor").header(HttpHeaders.AUTHORIZATION, bearer(doctorToken)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.patientsFollowed", greaterThanOrEqualTo(1)))
                .andExpect(jsonPath("$.upcomingPerDay", hasSize(7)))
                // Le rendez-vous de démo est accepté : le taux est défini et borné
                .andExpect(jsonPath("$.acceptanceRate", allOf(greaterThan(0.0), lessThanOrEqualTo(100.0))))
                .andExpect(jsonPath("$.topMedicines", hasSize(lessThanOrEqualTo(5))));
    }

    @Test
    void stats_areRestrictedToTheirOwnRole() throws Exception {
        String patientToken = login("patient@demo.tn", DEMO_PASSWORD);
        mockMvc.perform(get("/api/stats/doctor").header(HttpHeaders.AUTHORIZATION, bearer(patientToken)))
                .andExpect(status().isForbidden());

        String doctorToken = login("doctor@demo.tn", DEMO_PASSWORD);
        mockMvc.perform(get("/api/stats/patient").header(HttpHeaders.AUTHORIZATION, bearer(doctorToken)))
                .andExpect(status().isForbidden());
    }
}
