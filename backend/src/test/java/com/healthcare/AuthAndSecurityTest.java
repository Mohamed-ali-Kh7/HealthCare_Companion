package com.healthcare;

import org.junit.jupiter.api.Test;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;

import java.util.Map;

import static org.hamcrest.Matchers.notNullValue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class AuthAndSecurityTest extends AbstractIntegrationTest {

    @Test
    void patientRegistration_returnsTokenUsableOnProtectedEndpoint() throws Exception {
        String body = json(Map.of(
                "email", "Nouveau.Patient@Test.tn",
                "password", "Secret123",
                "firstName", "Sami",
                "lastName", "Haddad"));

        String response = mockMvc.perform(post("/api/auth/register/patient")
                        .contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.accessToken", notNullValue()))
                .andExpect(jsonPath("$.user.email").value("nouveau.patient@test.tn"))
                .andExpect(jsonPath("$.user.role").value("PATIENT"))
                .andReturn().getResponse().getContentAsString();

        String token = objectMapper.readTree(response).get("accessToken").asText();
        mockMvc.perform(get("/api/patients/me").header(HttpHeaders.AUTHORIZATION, bearer(token)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.firstName").value("Sami"));
    }

    @Test
    void duplicateEmail_returns409WithStableCode() throws Exception {
        String body = json(Map.of("email", "patient@demo.tn", "password", "Secret123",
                "firstName", "X", "lastName", "Y"));
        mockMvc.perform(post("/api/auth/register/patient").contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("EMAIL_ALREADY_USED"));
    }

    @Test
    void weakPassword_returns400WithFieldError() throws Exception {
        String body = json(Map.of("email", "weak@test.tn", "password", "abc",
                "firstName", "X", "lastName", "Y"));
        mockMvc.perform(post("/api/auth/register/patient").contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"))
                .andExpect(jsonPath("$.errors.password", notNullValue()));
    }

    @Test
    void wrongPassword_returnsGeneric401() throws Exception {
        mockMvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("email", "patient@demo.tn", "password", "Mauvais123"))))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("INVALID_CREDENTIALS"));
    }

    @Test
    void doctorRegistration_isPendingUntilAdminApproval() throws Exception {
        String body = json(Map.of("email", "new.doctor@test.tn", "password", "Secret123",
                "firstName", "Leila", "lastName", "Mansour", "specialityId", 1, "address", "Sfax"));
        mockMvc.perform(post("/api/auth/register/doctor").contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isAccepted())
                .andExpect(jsonPath("$.enabled").value(false));

        // Bon mot de passe mais compte en attente : 403 explicite (le mot de passe a été vérifié avant)
        mockMvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("email", "new.doctor@test.tn", "password", "Secret123"))))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("ACCOUNT_DISABLED"));
    }

    @Test
    void missingOrInvalidToken_returns401WithReason() throws Exception {
        mockMvc.perform(get("/api/appointments/my"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("AUTHENTICATION_REQUIRED"));

        mockMvc.perform(get("/api/appointments/my").header(HttpHeaders.AUTHORIZATION, "Bearer abc.def.ghi"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("TOKEN_INVALID"));
    }

    @Test
    void patientCannotAccessAdminEndpoints() throws Exception {
        String token = login("patient@demo.tn", DEMO_PASSWORD);
        mockMvc.perform(get("/api/users").header(HttpHeaders.AUTHORIZATION, bearer(token)))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("ACCESS_DENIED"));
        mockMvc.perform(get("/api/admin/dashboard").header(HttpHeaders.AUTHORIZATION, bearer(token)))
                .andExpect(status().isForbidden());
    }

    @Test
    void specialitiesArePublic() throws Exception {
        mockMvc.perform(get("/api/specialities"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].name", notNullValue()));
    }
}
