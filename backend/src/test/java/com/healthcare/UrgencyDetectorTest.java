package com.healthcare;

import com.healthcare.assistant.UrgencyDetector;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.junit.jupiter.params.provider.ValueSource;

import static org.assertj.core.api.Assertions.assertThat;

/** Filet de sécurité de l'assistant : doit repérer les signes d'alerte, quelle que soit l'orthographe des accents. */
class UrgencyDetectorTest {

    private final UrgencyDetector detector = new UrgencyDetector();

    @ParameterizedTest
    @CsvSource(delimiter = '|', value = {
            "J'ai une douleur à la poitrine depuis 20 minutes | douleur thoracique",
            "j ai MAL A LA POITRINE et au bras gauche | douleur thoracique",
            "Mon père n'arrive pas à respirer | détresse respiratoire",
            "ma fille s'est évanouie | perte de connaissance",
            "sa bouche est déformée et il parle mal | signes d'AVC",
            "Mon fils a des convulsions | convulsions",
            "je saigne beaucoup du nez depuis une heure | hémorragie",
            "ma gorge gonfle après avoir mangé des cacahuètes | réaction allergique grave",
            "j'ai avalé trop de comprimés | intoxication",
            "je n'ai plus envie de vivre | idées suicidaires",
    })
    void detecte_les_signes_d_alerte(String message, String expected) {
        assertThat(detector.detect(message)).contains(expected);
    }

    @ParameterizedTest
    @ValueSource(strings = {
            "Bonjour, comment renouveler mon ordonnance ?",
            "J'ai un peu mal à la tête avec la fatigue",
            "Est-ce que je peux prendre mon traitement avec du café ?",
            "J'avais de la fièvre hier, ça va mieux",
            "",
    })
    void ne_declenche_pas_sur_un_message_courant(String message) {
        assertThat(detector.detect(message)).isEmpty();
    }
}
