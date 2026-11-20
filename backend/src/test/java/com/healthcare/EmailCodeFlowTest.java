package com.healthcare;

import com.fasterxml.jackson.databind.JsonNode;
import com.healthcare.mail.MailService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MvcResult;

import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Envoi d'e-mails activé : inscription confirmée par code, mot de passe oublié.
 * MailService est simulé (aucun e-mail réel) : on lit le code dans le texte qu'il aurait envoyé.
 * Base H2 dédiée, pour ne pas toucher aux données des autres tests.
 */
@TestPropertySource(properties = {
        "app.mail.enabled=true",
        "spring.datasource.url=jdbc:h2:mem:healthcare-mail;MODE=MySQL;DATABASE_TO_LOWER=TRUE;DB_CLOSE_DELAY=-1"
})
class EmailCodeFlowTest extends AbstractIntegrationTest {

    private static final Pattern CODE = Pattern.compile("\\b(\\d{6})\\b");

    @MockitoBean
    private MailService mailService;

    @BeforeEach
    void mailEnabled() {
        reset(mailService);
        when(mailService.isEnabled()).thenReturn(true);
    }

    @Test
    void patientRegistration_requiresEmailCodeBeforeLogin() throws Exception {
        String email = "verif.patient@test.tn";
        mockMvc.perform(post("/api/auth/register/patient").contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("email", email, "password", "Secret123",
                                "firstName", "Amel", "lastName", "Ben Salah"))))
                .andExpect(status().isAccepted())
                .andExpect(jsonPath("$.accessToken").doesNotExist())
                .andExpect(jsonPath("$.user.emailVerified").value(false));
        String code = lastCodeSentTo(email);

        mockMvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("email", email, "password", "Secret123"))))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("EMAIL_NOT_VERIFIED"));

        mockMvc.perform(post("/api/auth/verify-email").contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("email", email, "code", wrong(code)))))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.code").value("INVALID_CODE"));

        mockMvc.perform(post("/api/auth/verify-email").contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("email", email, "code", code))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").isNotEmpty())
                .andExpect(jsonPath("$.user.emailVerified").value(true));

        login(email, "Secret123");
    }

    @Test
    void doctorRegistration_verifiedEmailStillWaitsForAdmin() throws Exception {
        String email = "verif.doctor@test.tn";
        mockMvc.perform(post("/api/auth/register/doctor").contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("email", email, "password", "Secret123", "firstName", "Sami",
                                "lastName", "Trabelsi", "specialityId", 1, "address", "Tunis"))))
                .andExpect(status().isAccepted())
                .andExpect(jsonPath("$.emailVerified").value(false));

        mockMvc.perform(post("/api/auth/verify-email").contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("email", email, "code", lastCodeSentTo(email)))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").doesNotExist())
                .andExpect(jsonPath("$.user.enabled").value(false))
                .andExpect(jsonPath("$.user.emailVerified").value(true));

        mockMvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("email", email, "password", "Secret123"))))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("ACCOUNT_DISABLED"));
    }

    @Test
    void forgotPassword_codeResetsPassword_andIsSingleUse() throws Exception {
        String email = registerVerifiedPatient("reset.patient@test.tn", "OldPass123");

        mockMvc.perform(post("/api/auth/forgot-password").contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("email", email))))
                .andExpect(status().isNoContent());
        String code = lastCodeSentTo(email);

        Map<String, String> reset = Map.of("email", email, "code", code, "newPassword", "NewPass456");
        mockMvc.perform(post("/api/auth/reset-password").contentType(MediaType.APPLICATION_JSON).content(json(reset)))
                .andExpect(status().isNoContent());

        login(email, "NewPass456");
        mockMvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("email", email, "password", "OldPass123"))))
                .andExpect(status().isUnauthorized());

        mockMvc.perform(post("/api/auth/reset-password").contentType(MediaType.APPLICATION_JSON).content(json(reset)))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.code").value("INVALID_CODE"));
    }

    @Test
    void forgotPassword_unknownEmail_answersTheSameAndSendsNothing() throws Exception {
        mockMvc.perform(post("/api/auth/forgot-password").contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("email", "nobody@test.tn"))))
                .andExpect(status().isNoContent());
        verify(mailService, never()).send(anyString(), anyString(), anyString(), anyString());
    }

    @Test
    void codeIsBlockedAfterTooManyWrongAttempts() throws Exception {
        String email = registerVerifiedPatient("brute.patient@test.tn", "OldPass123");
        mockMvc.perform(post("/api/auth/forgot-password").contentType(MediaType.APPLICATION_JSON)
                .content(json(Map.of("email", email))));
        String code = lastCodeSentTo(email);

        String lastError = null;
        for (int i = 0; i < 5; i++) {
            MvcResult result = mockMvc.perform(post("/api/auth/reset-password")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(json(Map.of("email", email, "code", wrong(code), "newPassword", "NewPass456"))))
                    .andExpect(status().isUnprocessableEntity())
                    .andReturn();
            JsonNode body = readJson(result);
            lastError = body.get("code").asText();
        }
        assertThat(lastError).isEqualTo("TOO_MANY_ATTEMPTS");

        // Même le bon code ne fonctionne plus : il faut en redemander un
        mockMvc.perform(post("/api/auth/reset-password").contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("email", email, "code", code, "newPassword", "NewPass456"))))
                .andExpect(status().isUnprocessableEntity());
    }

    private String registerVerifiedPatient(String email, String password) throws Exception {
        mockMvc.perform(post("/api/auth/register/patient").contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("email", email, "password", password,
                                "firstName", "Test", "lastName", "Patient"))))
                .andExpect(status().isAccepted());
        mockMvc.perform(post("/api/auth/verify-email").contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("email", email, "code", lastCodeSentTo(email)))))
                .andExpect(status().isOk());
        return email;
    }

    /** Code contenu dans le dernier e-mail (texte brut) envoyé à cette adresse. */
    private String lastCodeSentTo(String email) {
        ArgumentCaptor<String> text = ArgumentCaptor.forClass(String.class);
        verify(mailService, atLeastOnce()).send(eq(email), anyString(), text.capture(), anyString());
        Matcher matcher = CODE.matcher(text.getValue());
        assertThat(matcher.find()).as("code à 6 chiffres dans l'e-mail").isTrue();
        return matcher.group(1);
    }

    private static String wrong(String code) {
        return code.equals("000000") ? "111111" : "000000";
    }
}
