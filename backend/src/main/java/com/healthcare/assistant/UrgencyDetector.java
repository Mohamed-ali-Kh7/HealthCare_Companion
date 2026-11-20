package com.healthcare.assistant;

import org.springframework.stereotype.Component;

import java.text.Normalizer;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * Filet de sécurité déterministe : repère les signes d'alerte vitale dans le message du patient,
 * AVANT et indépendamment du modèle d'IA (qui peut être indisponible ou se tromper).
 * Volontairement sensible : un faux positif affiche une recommandation d'appeler le 190, un faux négatif est grave.
 */
@Component
public class UrgencyDetector {

    /** Motif → expressions (minuscules, sans accents). */
    private static final Map<String, List<String>> RED_FLAGS = new LinkedHashMap<>();

    static {
        RED_FLAGS.put("douleur thoracique", List.of("douleur thoracique", "douleur a la poitrine", "douleur dans la poitrine",
                "mal a la poitrine", "serrement dans la poitrine", "oppression thoracique", "poitrine qui serre",
                "crise cardiaque", "infarctus"));
        RED_FLAGS.put("détresse respiratoire", List.of("n'arrive pas a respirer", "narrive pas a respirer", "ne respire plus",
                "difficulte a respirer", "difficultes a respirer", "j'etouffe", "il etouffe", "elle etouffe", "suffoque",
                "levres bleues", "manque d'air"));
        RED_FLAGS.put("perte de connaissance", List.of("perte de connaissance", "perdu connaissance", "evanoui",
                "inconscient", "inconsciente", "ne se reveille pas", "ne repond plus", "malaise grave"));
        RED_FLAGS.put("signes d'AVC", List.of("avc", "visage paralyse", "visage est paralyse", "bouche deformee",
                "bouche est deformee", "bouche de travers", "bouche est de travers", "visage de travers",
                "n'arrive plus a parler", "narrive plus a parler", "trouble de la parole", "difficulte a parler",
                "parle difficilement", "paralysie", "bras qui ne repond plus", "faiblesse d'un cote",
                "engourdissement d'un cote"));
        RED_FLAGS.put("convulsions", List.of("convulsion", "convulse", "crise d'epilepsie", "crise epileptique"));
        RED_FLAGS.put("hémorragie", List.of("hemorragie", "saigne beaucoup", "saignement abondant", "saignement important",
                "vomit du sang", "crache du sang", "sang dans les selles"));
        RED_FLAGS.put("réaction allergique grave", List.of("choc anaphylactique", "anaphylaxie", "gorge gonfle",
                "gorge qui gonfle", "langue gonfle", "visage gonfle"));
        RED_FLAGS.put("intoxication", List.of("overdose", "surdose", "surdosage", "avale trop de", "intoxication",
                "empoisonne", "produit menager"));
        RED_FLAGS.put("idées suicidaires", List.of("suicide", "me suicider", "me tuer", "en finir avec la vie",
                "envie de mourir", "plus envie de vivre", "me faire du mal"));
        RED_FLAGS.put("traumatisme grave", List.of("accident grave", "chute grave", "fracture ouverte", "brulure grave",
                "traumatisme cranien", "coup a la tete"));
    }

    /** Motif d'urgence détecté, ou vide. */
    public Optional<String> detect(String message) {
        if (message == null || message.isBlank()) {
            return Optional.empty();
        }
        String text = normalize(message);
        for (Map.Entry<String, List<String>> flag : RED_FLAGS.entrySet()) {
            for (String expression : flag.getValue()) {
                if (text.contains(expression)) {
                    return Optional.of(flag.getKey());
                }
            }
        }
        return Optional.empty();
    }

    static String normalize(String s) {
        String noAccents = Normalizer.normalize(s, Normalizer.Form.NFD).replaceAll("\\p{M}", "");
        return noAccents.toLowerCase().replace('’', '\'').replaceAll("\\s+", " ");
    }
}
