package com.healthcare;

import com.healthcare.assistant.AssistantToolbox.PatientSnapshot;
import com.healthcare.assistant.SymptomAdvisor;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/** Sécurité des conseils sans IA : un médicament contre-indiqué par le dossier n'est jamais proposé. */
class SymptomAdvisorTest {

    private final SymptomAdvisor advisor = new SymptomAdvisor();

    private String advise(String text, PatientSnapshot p) {
        return advisor.advise(text, p).orElseThrow();
    }

    @Test
    void allergie_aux_anti_inflammatoires_exclut_l_ibuprofene() {
        String r = advise("mal a la tete", new PatientSnapshot(34, "Aspirine, ibuprofène", List.of()));
        assertThat(r).contains("Paracétamol :").doesNotContain("Ibuprofène (anti-inflammatoire) :")
                .contains("non proposé : allergie notée dans votre dossier");
    }

    @Test
    void allergie_au_paracetamol_l_exclut() {
        String r = advise("fievre", new PatientSnapshot(40, "Paracétamol", List.of()));
        assertThat(r).doesNotContain("Paracétamol :").contains("Demandez conseil à votre pharmacien");
    }

    @Test
    void anticoagulant_exclut_l_ibuprofene() {
        String r = advise("mal au dos", new PatientSnapshot(50, null, List.of("Sintrom acenocoumarol")));
        assertThat(r).doesNotContain("Ibuprofène (anti-inflammatoire) :").contains("anticoagulant");
    }

    @Test
    void apres_65_ans_pas_d_ibuprofene_sans_avis() {
        assertThat(advise("mal a la tete", new PatientSnapshot(70, null, List.of())))
                .contains("après 65 ans").doesNotContain("Ibuprofène (anti-inflammatoire) :");
    }

    @Test
    void enfant_pas_de_dose_adulte() {
        String r = advise("fievre", new PatientSnapshot(9, null, List.of()));
        assertThat(r).contains("dose selon le poids de l'enfant").doesNotContain("1 g par prise");
    }

    @Test
    void penicilline_n_exclut_pas_le_paracetamol() {
        assertThat(advise("fievre", new PatientSnapshot(31, "Pénicilline", List.of()))).contains("Paracétamol : 500 mg");
    }

    @Test
    void aucun_symptome_reconnu() {
        assertThat(advisor.advise("bonjour", new PatientSnapshot(30, null, List.of()))).isEmpty();
    }
}
