package com.healthcare;

import com.fasterxml.jackson.databind.JsonNode;
import com.healthcare.ambulance.TransportMissionEvent;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.context.event.ApplicationEvents;
import org.springframework.test.context.event.RecordApplicationEvents;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.containsString;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Cycle de vie d'un transport confié à une société conventionnée, en dehors du parcours nominal :
 * annulation par le patient et clôture anticipée.
 */
@RecordApplicationEvents
class AmbulanceMissionLifecycleTest extends AbstractIntegrationTest {

    private static final String BASE = "/api/ambulance-requests";

    @Autowired
    private ApplicationEvents events;

    @Test
    void cancellationByPatient_isPushedToCompany_andMissionCannotGoOn() throws Exception {
        Actors a = actors();
        long id = acceptedTransport(a, 6);

        events.clear();
        mockMvc.perform(put(BASE + "/" + id + "/cancel").header(HttpHeaders.AUTHORIZATION, bearer(a.patient)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("CANCELLED"));

        // La société est prévenue en direct (ainsi que le médecin)
        assertThat(events.stream(TransportMissionEvent.class)
                .filter(e -> e.request().id() == id)
                .anyMatch(e -> e.recipientUserIds().contains(a.companyUserId)
                        && e.recipientUserIds().contains(a.doctorUserId)))
                .isTrue();

        // Elle ne peut plus faire avancer la mission, avec un motif explicite
        mockMvc.perform(put(BASE + "/" + id + "/mission/advance").header(HttpHeaders.AUTHORIZATION, bearer(a.company)))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.detail", containsString("annulé par le patient")));
    }

    @Test
    void transportInProgress_cannotBeClosedBeforeArrival_andStaysBillable() throws Exception {
        Actors a = actors();
        long id = acceptedTransport(a, 7);
        mockMvc.perform(put(BASE + "/" + id + "/mission/advance").header(HttpHeaders.AUTHORIZATION, bearer(a.company)))
                .andExpect(jsonPath("$.mission.status").value("EN_ROUTE"));

        // Ni le médecin ni le patient ne peuvent clôturer pendant le trajet
        for (String token : new String[]{a.doctor, a.patient}) {
            mockMvc.perform(put(BASE + "/" + id + "/close").header(HttpHeaders.AUTHORIZATION, bearer(token)))
                    .andExpect(status().isUnprocessableEntity())
                    .andExpect(jsonPath("$.code").value("MISSION_IN_PROGRESS"));
        }

        // La société termine le trajet : la demande est clôturée et le transport peut être facturé
        for (String step : new String[]{"ON_SITE", "IN_TRANSIT", "ARRIVED"}) {
            mockMvc.perform(put(BASE + "/" + id + "/mission/advance").header(HttpHeaders.AUTHORIZATION, bearer(a.company)))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.mission.status").value(step));
        }
        JsonNode toInvoice = readJson(mockMvc.perform(get("/api/billing/company/to-invoice")
                .header(HttpHeaders.AUTHORIZATION, bearer(a.company))).andExpect(status().isOk()).andReturn());
        boolean listed = false;
        for (JsonNode t : toInvoice) {
            listed |= t.get("ambulanceRequestId").asLong() == id;
        }
        assertThat(listed).isTrue();
    }

    @Test
    void transportAwaitingCompanyAnswer_canStillBeClosed_andCompanyIsTold() throws Exception {
        Actors a = actors();
        long id = transportEntrustedToCompany(a, 8);

        events.clear();
        mockMvc.perform(put(BASE + "/" + id + "/close").header(HttpHeaders.AUTHORIZATION, bearer(a.doctor)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("CLOSED"));
        assertThat(events.stream(TransportMissionEvent.class)
                .anyMatch(e -> e.request().id() == id && e.recipientUserIds().contains(a.companyUserId)))
                .isTrue();

        // Plus rien à accepter côté société
        long vehicleId = readJson(mockMvc.perform(get("/api/transport/vehicles")
                .header(HttpHeaders.AUTHORIZATION, bearer(a.company))).andReturn()).get(0).get("id").asLong();
        mockMvc.perform(put(BASE + "/" + id + "/mission/accept").header(HttpHeaders.AUTHORIZATION, bearer(a.company))
                        .contentType(MediaType.APPLICATION_JSON).content(json(Map.of("vehicleId", vehicleId))))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.detail", containsString("terminé")));
    }

    // ---------------------------------------------------------------- Préparation

    private record Actors(String patient, String doctor, String company, long doctorId, long doctorUserId,
                          long companyId, long companyUserId) {
    }

    private Actors actors() throws Exception {
        String patient = login("patient2@demo.tn", DEMO_PASSWORD);
        String doctor = login("doctor@demo.tn", DEMO_PASSWORD);
        String company = login("ambulance@demo.tn", DEMO_PASSWORD);
        long doctorId = readJson(mockMvc.perform(get("/api/doctors/me")
                .header(HttpHeaders.AUTHORIZATION, bearer(doctor))).andReturn()).get("id").asLong();
        long companyId = readJson(mockMvc.perform(get("/api/transport/companies/me")
                .header(HttpHeaders.AUTHORIZATION, bearer(company))).andReturn()).get("id").asLong();
        return new Actors(patient, doctor, company, doctorId, userId(doctor), companyId, userId(company));
    }

    private long userId(String token) throws Exception {
        return readJson(mockMvc.perform(get("/api/auth/me").header(HttpHeaders.AUTHORIZATION, bearer(token)))
                .andExpect(status().isOk()).andReturn()).get("id").asLong();
    }

    /** Transport validé par le médecin et confié à la société (en attente de sa réponse). */
    private long transportEntrustedToCompany(Actors a, int daysAhead) throws Exception {
        String when = LocalDateTime.now().plusDays(daysAhead).withHour(10).withMinute(0).withSecond(0).withNano(0)
                .format(DateTimeFormatter.ISO_LOCAL_DATE_TIME);
        long id = readJson(mockMvc.perform(post(BASE).header(HttpHeaders.AUTHORIZATION, bearer(a.patient))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("type", "SCHEDULED", "doctorId", a.doctorId, "scheduledAt", when,
                                "address", "5 rue Ibn Khaldoun, Tunis", "latitude", 36.819, "longitude", 10.166))))
                .andExpect(status().isCreated()).andReturn()).get("id").asLong();
        mockMvc.perform(put(BASE + "/" + id + "/approve").header(HttpHeaders.AUTHORIZATION, bearer(a.doctor)))
                .andExpect(status().isOk());
        mockMvc.perform(put(BASE + "/" + id + "/company").header(HttpHeaders.AUTHORIZATION, bearer(a.patient))
                        .contentType(MediaType.APPLICATION_JSON).content(json(Map.of("companyId", a.companyId))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.mission.status").value("REQUESTED"));
        return id;
    }

    /** Idem, puis accepté par la société avec un véhicule. */
    private long acceptedTransport(Actors a, int daysAhead) throws Exception {
        long id = transportEntrustedToCompany(a, daysAhead);
        long vehicleId = readJson(mockMvc.perform(get("/api/transport/vehicles")
                .header(HttpHeaders.AUTHORIZATION, bearer(a.company))).andReturn()).get(0).get("id").asLong();
        mockMvc.perform(put(BASE + "/" + id + "/mission/accept").header(HttpHeaders.AUTHORIZATION, bearer(a.company))
                        .contentType(MediaType.APPLICATION_JSON).content(json(Map.of("vehicleId", vehicleId))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.mission.status").value("ACCEPTED"));
        return id;
    }
}
