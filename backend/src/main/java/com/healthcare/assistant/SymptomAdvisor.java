package com.healthcare.assistant;

import com.healthcare.assistant.AssistantToolbox.PatientSnapshot;
import org.springframework.stereotype.Component;

import java.util.*;

/**
 * Conseils de premier niveau par symptôme, sans IA (mode de secours) : gestes simples, médicament courant
 * SANS ORDONNANCE avec la posologie adulte usuelle, signes qui doivent faire consulter.
 * Chaque médicament est vérifié contre le dossier (allergies, traitements en cours, âge) : en cas de doute,
 * il n'est pas proposé et le patient est renvoyé vers le pharmacien ou le médecin.
 * Jamais de médicament sur ordonnance (antibiotiques, corticoïdes...).
 */
@Component
public class SymptomAdvisor {

    /** Médicaments sans ordonnance proposés. */
    enum Otc {
        PARACETAMOL("Paracétamol", "500 mg à 1 g par prise, au moins 4 à 6 h entre deux prises, 3 g par jour au maximum",
                List.of("paracetamol", "doliprane", "efferalgan")),
        IBUPROFEN("Ibuprofène (anti-inflammatoire)",
                "200 à 400 mg par prise pendant le repas, toutes les 6 à 8 h, 1 200 mg par jour au maximum, 3 jours au plus "
                        + "(à éviter pendant la grossesse et en cas d'ulcère de l'estomac)",
                List.of("ibuprofene", "anti-inflammatoire", "ains", "aspirine", "advil", "brufen")),
        ANTACID("Antiacide (gel ou comprimé à croquer)", "1 prise après les repas et au coucher, selon la notice",
                List.of("antiacide")),
        ORS("Soluté de réhydratation orale (SRO)", "à boire par petites gorgées tout au long de la journée",
                List.of()),
        CETIRIZINE("Antihistaminique (cétirizine)", "10 mg une fois par jour, de préférence le soir (peut endormir)",
                List.of("cetirizine", "antihistaminique")),
        SALINE("Sérum physiologique", "lavage du nez plusieurs fois par jour", List.of());

        final String label;
        final String dose;
        /** Allergies qui l'excluent (texte normalisé). */
        final List<String> allergyKeys;

        Otc(String label, String dose, List<String> allergyKeys) {
            this.label = label;
            this.dose = dose;
            this.allergyKeys = allergyKeys;
        }
    }

    record Advice(String title, List<String> keywords, List<String> care, List<Otc> medicines, List<String> seeDoctor) {
    }

    private static final List<Advice> CATALOG = List.of(
            new Advice("Fièvre", List.of("fievre", "temperature", "38", "39", "frissons", "chaud"),
                    List.of("Reposez-vous et buvez beaucoup (eau, jus, bouillon)",
                            "Portez des vêtements légers, ne vous couvrez pas trop",
                            "Mesurez la température matin et soir et notez-la dans votre journal (onglet Santé)"),
                    List.of(Otc.PARACETAMOL),
                    List.of("fièvre au-dessus de 39,5 °C ou qui dure plus de 3 jours",
                            "raideur de la nuque, taches sur la peau, gêne pour respirer, confusion",
                            "fièvre chez un nourrisson de moins de 3 mois")),
            new Advice("Maux de tête", List.of("mal a la tete", "maux de tete", "migraine", "cephalee"),
                    List.of("Reposez-vous au calme et dans la pénombre", "Buvez de l'eau, évitez les écrans",
                            "Une compresse fraîche sur le front peut soulager"),
                    List.of(Otc.PARACETAMOL, Otc.IBUPROFEN),
                    List.of("mal de tête brutal et très intense, le pire de votre vie",
                            "mal de tête avec fièvre et raideur de la nuque, ou après un choc à la tête",
                            "maux de tête qui durent plus de 3 jours malgré le traitement")),
            new Advice("Rhume, nez bouché, toux", List.of("rhume", "nez bouche", "nez qui coule", "toux", "tousse", "enrhume"),
                    List.of("Reposez-vous et buvez chaud (tisane, eau tiède avec du miel et du citron)",
                            "Aérez votre chambre et dormez la tête légèrement surélevée",
                            "Le miel calme la toux (pas avant 1 an)"),
                    List.of(Otc.SALINE, Otc.PARACETAMOL),
                    List.of("essoufflement, douleur dans la poitrine en respirant",
                            "toux qui dure plus de 3 semaines ou crachats avec du sang",
                            "fièvre élevée qui revient après quelques jours")),
            new Advice("Mal de gorge", List.of("mal a la gorge", "gorge", "angine", "avaler"),
                    List.of("Buvez souvent, chaud ou froid selon ce qui soulage",
                            "Sucez des pastilles ou du miel, gargarisez-vous à l'eau tiède salée",
                            "Reposez votre voix"),
                    List.of(Otc.PARACETAMOL),
                    List.of("difficulté à avaler la salive ou à respirer", "fièvre au-dessus de 38,5 °C",
                            "pas d'amélioration après 3 jours (une angine peut nécessiter un antibiotique prescrit)")),
            new Advice("Diarrhée", List.of("diarrhee", "selles liquides", "gastro"),
                    List.of("Buvez beaucoup pour éviter la déshydratation",
                            "Mangez léger : riz, carottes cuites, banane, compote ; évitez laitages, fritures et crudités",
                            "Lavez-vous souvent les mains"),
                    List.of(Otc.ORS),
                    List.of("sang dans les selles, fièvre élevée",
                            "signes de déshydratation : bouche sèche, très peu d'urines, vertiges",
                            "diarrhée qui dure plus de 48 h, ou chez un enfant ou une personne âgée")),
            new Advice("Nausées, vomissements", List.of("nausee", "vomi", "envie de vomir", "mal au coeur"),
                    List.of("Buvez par petites gorgées, souvent (eau, SRO)",
                            "Mangez léger et en petites quantités quand cela va mieux"),
                    List.of(Otc.ORS),
                    List.of("vomissements qui empêchent de boire pendant plus de 24 h",
                            "vomissements de sang, fortes douleurs au ventre, mal de tête intense")),
            new Advice("Brûlures d'estomac", List.of("brulure d'estomac", "brulures d'estomac", "acidite", "reflux", "aigreur"),
                    List.of("Mangez plus lentement, en petites portions", "Évitez café, alcool, épices et repas tardifs",
                            "Surélevez la tête du lit"),
                    List.of(Otc.ANTACID),
                    List.of("douleur intense ou qui irradie dans la poitrine, le dos ou le bras",
                            "selles noires, vomissements de sang, perte de poids")),
            new Advice("Douleurs musculaires ou du dos", List.of("mal au dos", "douleur au dos", "lombalgie", "courbature",
                    "douleur musculaire", "torticolis"),
                    List.of("Restez actif doucement : le repos complet retarde la guérison",
                            "Appliquez de la chaleur (bouillotte, douche chaude)"),
                    List.of(Otc.PARACETAMOL, Otc.IBUPROFEN),
                    List.of("douleur après une chute ou un accident",
                            "fourmillements, faiblesse dans une jambe, troubles pour uriner",
                            "douleur qui dure plus d'une semaine")),
            new Advice("Allergie saisonnière", List.of("allergie", "eternue", "yeux qui piquent", "rhinite", "pollen"),
                    List.of("Rincez le nez au sérum physiologique", "Évitez les sorties par temps sec et venteux",
                            "Aérez tôt le matin ou tard le soir"),
                    List.of(Otc.CETIRIZINE, Otc.SALINE),
                    List.of("gonflement du visage, des lèvres ou de la gorge, gêne pour respirer (urgence)",
                            "sifflements dans la poitrine")));

    /** Médicaments qui contre-indiquent l'ibuprofène (anticoagulants, antiagrégants). */
    private static final List<String> BLOOD_THINNERS = List.of("warfarine", "acenocoumarol", "sintrom", "apixaban",
            "rivaroxaban", "dabigatran", "clopidogrel", "aspirine", "kardegic", "heparine");

    /** Conseils correspondant au message (au plus 2 symptômes), ou vide si aucun symptôme reconnu. */
    public Optional<String> advise(String normalizedText, PatientSnapshot patient) {
        List<Advice> matched = CATALOG.stream()
                .filter(a -> a.keywords().stream().anyMatch(normalizedText::contains))
                .limit(2)
                .toList();
        if (matched.isEmpty()) {
            return Optional.empty();
        }
        StringBuilder out = new StringBuilder();
        out.append(matched.stream().map(Advice::title).reduce((a, b) -> a + " et " + b.toLowerCase()).orElse(""))
                .append(" : voici ce que vous pouvez faire.\n\n");

        out.append("🛌 Repos et soins\n");
        matched.stream().flatMap(a -> a.care().stream()).distinct().limit(5)
                .forEach(c -> out.append("- ").append(c).append('\n'));

        String allergies = UrgencyDetector.normalize(Objects.toString(patient.allergies(), ""));
        String meds = UrgencyDetector.normalize(String.join(" ", patient.currentMedicines()));
        Set<Otc> medicines = new LinkedHashSet<>();
        matched.forEach(a -> medicines.addAll(a.medicines()));
        List<String> notes = new ArrayList<>();

        out.append("\n💊 Médicament sans ordonnance\n");
        boolean child = patient.age() != null && patient.age() < 15;
        int proposed = 0;
        for (Otc m : medicines) {
            Optional<String> excluded = exclusion(m, allergies, meds, patient.age());
            if (excluded.isPresent()) {
                notes.add(excluded.get());
                continue;
            }
            out.append("- ").append(m.label).append(" : ")
                    .append(child && (m == Otc.PARACETAMOL || m == Otc.IBUPROFEN || m == Otc.CETIRIZINE)
                            ? "dose selon le poids de l'enfant, demandez au pharmacien"
                            : m.dose)
                    .append('\n');
            proposed++;
        }
        if (proposed == 0) {
            out.append("- Demandez conseil à votre pharmacien avant de prendre un médicament\n");
        }
        if (out.indexOf("- " + Otc.PARACETAMOL.label + " :") >= 0 && out.indexOf("- " + Otc.IBUPROFEN.label + " :") >= 0) {
            out.append("Commencez par le paracétamol ; ne prenez pas les deux en même temps sans avis du pharmacien.\n");
        }
        notes.forEach(n -> out.append("⚠️ ").append(n).append('\n'));
        out.append("Lisez la notice. Si vous suivez déjà un traitement, demandez l'avis du pharmacien.\n");

        out.append("\n🩺 Consultez votre médecin si\n");
        matched.stream().flatMap(a -> a.seeDoctor().stream()).distinct().limit(5)
                .forEach(s -> out.append("- ").append(s).append('\n'));
        return Optional.of(out.toString().trim());
    }

    /** Raison de ne pas proposer ce médicament à ce patient, ou vide s'il peut l'être. */
    static Optional<String> exclusion(Otc m, String allergies, String currentMeds, Integer age) {
        for (String key : m.allergyKeys) {
            if (allergies.contains(key)) {
                return Optional.of(m.label + " non proposé : allergie notée dans votre dossier (" + key + ").");
            }
        }
        if (m == Otc.IBUPROFEN) {
            if (BLOOD_THINNERS.stream().anyMatch(currentMeds::contains)) {
                return Optional.of("Ibuprofène non proposé : il est déconseillé avec votre traitement anticoagulant "
                        + "ou antiagrégant.");
            }
            if (age != null && age >= 65) {
                return Optional.of("Ibuprofène non proposé après 65 ans sans avis médical : préférez le paracétamol.");
            }
        }
        return Optional.empty();
    }
}
