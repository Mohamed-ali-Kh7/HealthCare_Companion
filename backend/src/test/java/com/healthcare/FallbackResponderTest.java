package com.healthcare;

import com.healthcare.assistant.AssistantToolbox;
import com.healthcare.assistant.AssistantToolbox.PatientSnapshot;
import com.healthcare.assistant.FallbackResponder;
import com.healthcare.assistant.SymptomAdvisor;
import com.healthcare.security.SecurityUser;
import com.healthcare.user.Role;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/** Mode de secours de l'assistant (sans IA) : conseils par symptôme, transfert, rappel d'urgence. */
class FallbackResponderTest {

    private final AssistantToolbox toolbox = mock(AssistantToolbox.class);
    private final FallbackResponder responder = new FallbackResponder(toolbox, new SymptomAdvisor());
    private final SecurityUser patient = new SecurityUser(7L, "p@x.tn", "x", Role.PATIENT, true);

    @BeforeEach
    void adultWithoutAllergy() {
        when(toolbox.snapshot(any())).thenReturn(new PatientSnapshot(30, null, List.of()));
    }

    private String reply(String message) {
        return responder.reply(patient, message, Optional.empty(), new AssistantToolbox.Outcome());
    }

    @Test
    void fievre_soins_paracetamol_et_rappel_d_urgence() {
        String r = reply("J'ai de la fièvre depuis hier");
        assertThat(r).startsWith("Fièvre")
                .contains("🛌 Repos et soins", "buvez beaucoup")
                .contains("💊 Médicament sans ordonnance", "Paracétamol : 500 mg à 1 g par prise")
                .contains("🩺 Consultez votre médecin si")
                .endsWith(FallbackResponder.EMERGENCY_FOOTER);
    }

    @Test
    void deux_symptomes_sont_combines() {
        String r = reply("j'ai de la fièvre et mal à la tête");
        assertThat(r).startsWith("Fièvre et maux de tête").contains("Paracétamol", "Ibuprofène")
                .contains("Commencez par le paracétamol ; ne prenez pas les deux en même temps");
    }

    @Test
    void transfert_sans_message_explique_l_absence() {
        String r = reply("(Transfert depuis la messagerie : Dr Karim Trabelsi n'est pas disponible pour le moment.)\n"
                + "J'ai besoin d'aide en attendant son retour.");
        assertThat(r).contains("indisponible").doesNotContain("Pharmacies").endsWith(FallbackResponder.EMERGENCY_FOOTER);
    }

    @Test
    void transfert_repond_au_contenu_des_messages_cites() {
        String r = reply("(Transfert depuis la messagerie : Dr Karim Trabelsi est absent jusqu'au 16/11/2026.)\n"
                + "Voici ce que je lui avais écrit :\n« J'ai de la fièvre à 38.5 depuis hier »\n");
        assertThat(r).contains("je vous réponds en attendant son retour", "Fièvre", "Paracétamol");
    }

    @Test
    void la_question_sur_la_pharmacie_reste_reconnue() {
        assertThat(reply("Où trouver ce médicament en pharmacie ?")).contains("Pharmacies");
    }
}
