package com.healthcare;

import com.fasterxml.jackson.databind.JsonNode;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Ambulances conventionnées : transport validé par le médecin → confié à une société → accepté avec un véhicule →
 * trajet suivi étape par étape → facturé par la société → payé par le patient.
 */
class AmbulanceCompanyTest extends AbstractIntegrationTest {

    @Test
    void scheduledTransport_isCarriedOutAndInvoicedByContractedCompany() throws Exception {
        String patient = login("patient2@demo.tn", DEMO_PASSWORD);
        String doctor = login("doctor@demo.tn", DEMO_PASSWORD);
        String company = login("ambulance@demo.tn", DEMO_PASSWORD);
        String otherCompany = login("ambulance2@demo.tn", DEMO_PASSWORD);

        // Le patient demande un transport, le Dr Trabelsi le valide
        long doctorId = readJson(mockMvc.perform(get("/api/doctors/me")
                .header(HttpHeaders.AUTHORIZATION, bearer(doctor))).andReturn()).get("id").asLong();
        String when = LocalDateTime.now().plusDays(3).withHour(9).withMinute(0)
                .format(DateTimeFormatter.ISO_LOCAL_DATE_TIME);
        long requestId = readJson(mockMvc.perform(post("/api/ambulance-requests")
                        .header(HttpHeaders.AUTHORIZATION, bearer(patient)).contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("type", "SCHEDULED", "doctorId", doctorId, "scheduledAt", when,
                                "address", "5 rue Ibn Khaldoun, Tunis", "latitude", 36.819, "longitude", 10.166,
                                "reason", "Examen IRM"))))
                .andExpect(status().isCreated()).andReturn()).get("id").asLong();

        // Impossible de choisir une société avant la validation du médecin
        long ennourId = nearbyCompanyId(patient, "Ambulances Ennour (démo)");
        mockMvc.perform(put("/api/ambulance-requests/" + requestId + "/company")
                        .header(HttpHeaders.AUTHORIZATION, bearer(patient)).contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("companyId", ennourId))))
                .andExpect(status().isUnprocessableEntity());

        mockMvc.perform(put("/api/ambulance-requests/" + requestId + "/approve")
                .header(HttpHeaders.AUTHORIZATION, bearer(doctor))).andExpect(status().isOk());

        // Le patient confie le transport à la société la plus proche
        mockMvc.perform(put("/api/ambulance-requests/" + requestId + "/company")
                        .header(HttpHeaders.AUTHORIZATION, bearer(patient)).contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("companyId", ennourId))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.mission.status").value("REQUESTED"))
                .andExpect(jsonPath("$.mission.company.name").value("Ambulances Ennour (démo)"));

        // Une autre société ne voit pas cette mission et ne peut pas l'accepter
        mockMvc.perform(put("/api/ambulance-requests/" + requestId + "/mission/advance")
                .header(HttpHeaders.AUTHORIZATION, bearer(otherCompany))).andExpect(status().isNotFound());

        // La société accepte avec un véhicule en service, puis fait avancer le trajet jusqu'à l'arrivée
        JsonNode vehicles = readJson(mockMvc.perform(get("/api/transport/vehicles")
                .header(HttpHeaders.AUTHORIZATION, bearer(company))).andExpect(status().isOk()).andReturn());
        long vehicleId = vehicles.get(0).get("id").asLong();
        mockMvc.perform(put("/api/ambulance-requests/" + requestId + "/mission/accept")
                        .header(HttpHeaders.AUTHORIZATION, bearer(company)).contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("vehicleId", vehicleId, "note", "Arrivée 10 min avant"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.mission.status").value("ACCEPTED"))
                .andExpect(jsonPath("$.mission.vehicle.plate").isNotEmpty());
        for (String expected : new String[]{"EN_ROUTE", "ON_SITE", "IN_TRANSIT", "ARRIVED"}) {
            mockMvc.perform(put("/api/ambulance-requests/" + requestId + "/mission/advance")
                            .header(HttpHeaders.AUTHORIZATION, bearer(company)))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.mission.status").value(expected));
        }
        // Arrivé : la demande est clôturée, aucune étape supplémentaire
        mockMvc.perform(get("/api/ambulance-requests/my").header(HttpHeaders.AUTHORIZATION, bearer(patient)))
                .andExpect(jsonPath("$[?(@.id == " + requestId + ")].status").value("CLOSED"));
        mockMvc.perform(put("/api/ambulance-requests/" + requestId + "/mission/advance")
                .header(HttpHeaders.AUTHORIZATION, bearer(company))).andExpect(status().isUnprocessableEntity());

        // La société facture le transport (tiers payant CNAM) ; un acte de consultation est refusé
        JsonNode toInvoice = readJson(mockMvc.perform(get("/api/billing/company/to-invoice")
                .header(HttpHeaders.AUTHORIZATION, bearer(company))).andExpect(status().isOk()).andReturn());
        boolean listed = false;
        for (JsonNode t : toInvoice) {
            listed |= t.get("ambulanceRequestId").asLong() == requestId;
        }
        assertThat(listed).isTrue();
        mockMvc.perform(post("/api/billing/company/invoices").header(HttpHeaders.AUTHORIZATION, bearer(company))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("ambulanceRequestId", requestId, "act", "CONSULTATION",
                                "amount", 60, "coverage", "NONE"))))
                .andExpect(status().isUnprocessableEntity());
        JsonNode invoice = readJson(mockMvc.perform(post("/api/billing/company/invoices")
                        .header(HttpHeaders.AUTHORIZATION, bearer(company)).contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("ambulanceRequestId", requestId, "act", "AMBULANCE_TRANSPORT",
                                "amount", 60, "coverage", "PRIVATE_SECTOR"))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.issuer.kind").value("AMBULANCE_COMPANY"))
                .andExpect(jsonPath("$.patientDue").value(18.0))
                .andReturn());

        // Le patient la voit et la paie ; la page de vérification indique un transport
        mockMvc.perform(post("/api/billing/my/invoices/" + invoice.get("id").asLong() + "/pay")
                        .header(HttpHeaders.AUTHORIZATION, bearer(patient)).contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("holder", "Youssef Hammami", "cardNumber", "4242424242424242",
                                "expiry", "12/30", "cvv", "123"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("PAID"));
        String url = invoice.get("verifyUrl").asText();
        String page = mockMvc.perform(get(url.substring(url.indexOf("/verify/invoice/")))).andReturn()
                .getResponse().getContentAsString(java.nio.charset.StandardCharsets.UTF_8);
        assertThat(page).contains("Facture authentique", "Ambulances Ennour", "Transport");
    }

    @Test
    void companyAccountWaitsForAdminValidation_andManagesItsFleet() throws Exception {
        // Inscription : compte créé mais désactivé jusqu'à la validation par l'administrateur
        mockMvc.perform(post("/api/auth/register/ambulance-company").contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("email", "nouvelle.ambulance@test.tn", "password", "Ambulance123",
                                "companyName", "Sfax Ambulances", "conventionNumber", "CNAM-AMB-0999",
                                "address", "Route de Tunis, Sfax", "city", "Sfax", "phone", "+216 74 000 000",
                                "latitude", 34.74, "longitude", 10.76))))
                .andExpect(status().isAccepted())
                .andExpect(jsonPath("$.role").value("AMBULANCE_COMPANY"))
                .andExpect(jsonPath("$.enabled").value(false));
        mockMvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("email", "nouvelle.ambulance@test.tn", "password", "Ambulance123"))))
                .andExpect(status().is4xxClientError());

        // Flotte : ajout d'un véhicule, immatriculation unique, mise hors service
        String company = login("ambulance2@demo.tn", DEMO_PASSWORD);
        long id = readJson(mockMvc.perform(post("/api/transport/vehicles")
                        .header(HttpHeaders.AUTHORIZATION, bearer(company)).contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("plate", "230 tu 9999", "type", "VSL", "driverName", "Sami"))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.plate").value("230 TU 9999"))
                .andReturn()).get("id").asLong();
        mockMvc.perform(post("/api/transport/vehicles")
                        .header(HttpHeaders.AUTHORIZATION, bearer(company)).contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("plate", "230 TU 9999", "type", "AMBULANCE"))))
                .andExpect(status().isConflict());
        mockMvc.perform(put("/api/transport/vehicles/" + id + "/service")
                        .header(HttpHeaders.AUTHORIZATION, bearer(company)).contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("inService", false))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.inService").value(false));

        // Un patient n'accède pas à l'espace société
        String patient = login("patient@demo.tn", DEMO_PASSWORD);
        mockMvc.perform(get("/api/transport/vehicles").header(HttpHeaders.AUTHORIZATION, bearer(patient)))
                .andExpect(status().isForbidden());
    }

    private long nearbyCompanyId(String token, String name) throws Exception {
        JsonNode companies = readJson(mockMvc.perform(get("/api/transport/companies/nearby")
                        .param("lat", "36.819").param("lng", "10.166")
                        .header(HttpHeaders.AUTHORIZATION, bearer(token)))
                .andExpect(status().isOk()).andReturn());
        assertThat(companies.size()).isGreaterThanOrEqualTo(2);
        assertThat(companies.get(0).get("distanceKm").asDouble())
                .isLessThanOrEqualTo(companies.get(1).get("distanceKm").asDouble());
        for (JsonNode c : companies) {
            if (c.get("name").asText().equals(name)) {
                return c.get("id").asLong();
            }
        }
        throw new AssertionError("Société introuvable : " + name);
    }
}
