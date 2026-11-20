package com.healthcare;

import com.fasterxml.jackson.databind.JsonNode;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Facturation : consultation terminée → facture → paiement simulé (refus puis acceptation) → QR vérifiable. */
class BillingTest extends AbstractIntegrationTest {

    @Test
    void doctorInvoices_patientPaysByCard_qrCodeVerifies() throws Exception {
        String doctor = login("doctor@demo.tn", DEMO_PASSWORD);
        String hammami = login("patient2@demo.tn", DEMO_PASSWORD);

        // Consultation terminée de démo, pas encore facturée
        JsonNode toInvoice = readJson(mockMvc.perform(get("/api/billing/doctor/to-invoice")
                .header(HttpHeaders.AUTHORIZATION, bearer(doctor))).andExpect(status().isOk()).andReturn());
        JsonNode pending = null;
        for (JsonNode n : toInvoice) {
            if (n.get("reason").asText().startsWith("Douleurs lombaires (suivi)")) {
                pending = n;
            }
        }
        assertThat(pending).as("consultation à facturer").isNotNull();
        long appointmentId = pending.get("appointmentId").asLong();
        assertThat(pending.get("suggestedAct").asText()).isEqualTo("CONSULTATION");

        // Facture en filière privée : 45 DT, CNAM 70 % → le patient ne paie que 13,500 DT
        Map<String, Object> request = Map.of("appointmentId", appointmentId, "act", "CONSULTATION",
                "amount", 45, "coverage", "PRIVATE_SECTOR");
        JsonNode invoice = readJson(mockMvc.perform(post("/api/billing/doctor/invoices")
                        .header(HttpHeaders.AUTHORIZATION, bearer(doctor))
                        .contentType(MediaType.APPLICATION_JSON).content(json(request)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.status").value("UNPAID"))
                .andExpect(jsonPath("$.cnamShare").value(31.5))
                .andExpect(jsonPath("$.patientDue").value(13.5))
                .andReturn());
        long invoiceId = invoice.get("id").asLong();
        assertThat(invoice.get("number").asText()).matches("F-\\d{4}-\\d{6}");

        // Une seule facture par consultation
        mockMvc.perform(post("/api/billing/doctor/invoices").header(HttpHeaders.AUTHORIZATION, bearer(doctor))
                        .contentType(MediaType.APPLICATION_JSON).content(json(request)))
                .andExpect(status().isConflict());

        // Un autre patient ne peut pas payer cette facture
        String amira = login("patient@demo.tn", DEMO_PASSWORD);
        mockMvc.perform(post("/api/billing/my/invoices/" + invoiceId + "/pay")
                        .header(HttpHeaders.AUTHORIZATION, bearer(amira))
                        .contentType(MediaType.APPLICATION_JSON).content(json(card("4242 4242 4242 4242"))))
                .andExpect(status().isNotFound());

        // Carte refusée par la banque (carte de test), puis carte acceptée
        mockMvc.perform(post("/api/billing/my/invoices/" + invoiceId + "/pay")
                        .header(HttpHeaders.AUTHORIZATION, bearer(hammami))
                        .contentType(MediaType.APPLICATION_JSON).content(json(card("4000 0000 0000 0002"))))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.code").value("PAYMENT_CARD_DECLINED"));
        mockMvc.perform(post("/api/billing/my/invoices/" + invoiceId + "/pay")
                        .header(HttpHeaders.AUTHORIZATION, bearer(hammami))
                        .contentType(MediaType.APPLICATION_JSON).content(json(card("4242 4242 4242 4242"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("PAID"))
                .andExpect(jsonPath("$.paymentMethod").value("CARD"))
                .andExpect(jsonPath("$.cardLast4").value("4242"));

        // Déjà réglée : pas de double paiement
        mockMvc.perform(post("/api/billing/my/invoices/" + invoiceId + "/pay")
                        .header(HttpHeaders.AUTHORIZATION, bearer(hammami))
                        .contentType(MediaType.APPLICATION_JSON).content(json(card("4242 4242 4242 4242"))))
                .andExpect(status().isUnprocessableEntity());

        // QR code : page publique authentique ; lien falsifié refusé
        String url = invoice.get("verifyUrl").asText();
        String path = url.substring(url.indexOf("/verify/invoice/"));
        String page = mockMvc.perform(get(path)).andExpect(status().isOk()).andReturn()
                .getResponse().getContentAsString(java.nio.charset.StandardCharsets.UTF_8);
        assertThat(page).contains("Facture authentique", invoice.get("number").asText(), "Réglée");
        mockMvc.perform(get("/verify/invoice/" + invoiceId + "-falsifie")).andExpect(status().isNotFound());
    }

    @Test
    void doctorSummary_andCardIsValidated() throws Exception {
        String doctor = login("doctor@demo.tn", DEMO_PASSWORD);

        // Tableau de bord médecin : la facture de démo réglée par carte compte dans le mois
        mockMvc.perform(get("/api/billing/doctor/summary").header(HttpHeaders.AUTHORIZATION, bearer(doctor)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.cnamRatePercent").value(70));

        // Factures du patient (démo : une réglée, une à payer)
        String amira = login("patient@demo.tn", DEMO_PASSWORD);
        JsonNode mine = readJson(mockMvc.perform(get("/api/billing/my/invoices")
                .header(HttpHeaders.AUTHORIZATION, bearer(amira))).andExpect(status().isOk()).andReturn());
        assertThat(mine.size()).isGreaterThanOrEqualTo(2);
        long unpaidId = -1;
        for (JsonNode i : mine) {
            if (i.get("status").asText().equals("UNPAID")) {
                unpaidId = i.get("id").asLong();
            }
        }
        assertThat(unpaidId).isPositive();

        // Carte invalide (Luhn) et carte expirée
        mockMvc.perform(post("/api/billing/my/invoices/" + unpaidId + "/pay")
                        .header(HttpHeaders.AUTHORIZATION, bearer(amira))
                        .contentType(MediaType.APPLICATION_JSON).content(json(card("4242 4242 4242 4241"))))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.code").value("PAYMENT_INVALID_CARD"));
        mockMvc.perform(post("/api/billing/my/invoices/" + unpaidId + "/pay")
                        .header(HttpHeaders.AUTHORIZATION, bearer(amira))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("holder", "Amira", "cardNumber", "4242424242424242",
                                "expiry", "01/20", "cvv", "123"))))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.code").value("PAYMENT_CARD_EXPIRED"));
    }

    private static Map<String, Object> card(String number) {
        return Map.of("holder", "Patient Test", "cardNumber", number, "expiry", "12/30", "cvv", "123");
    }
}
