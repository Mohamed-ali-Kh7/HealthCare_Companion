package com.healthcare.assistant;

import com.healthcare.assistant.dto.AssistantDtos.DoctorOption;
import com.healthcare.security.SecurityUser;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.Optional;

/**
 * Réponses sans IA (pas de clé API, service indisponible, demande refusée) : orientation par règles simples.
 * La détection d'urgence et la transmission au médecin fonctionnent aussi dans ce mode.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class FallbackResponder {

    private final AssistantToolbox toolbox;
    private final SymptomAdvisor advisor;

    public String reply(SecurityUser me, String message, Optional<String> urgency, AssistantToolbox.Outcome outcome) {
        if (urgency.isPresent()) {
            toolbox.reportEmergency(urgency.get(), outcome);
            // En urgence, les médecins du patient sont prévenus sans attendre (en plus du 190)
            for (DoctorOption d : toolbox.myDoctors(me)) {
                try {
                    toolbox.forwardToDoctor(me, d.id(), "Signe d'alerte repéré automatiquement (" + urgency.get()
                            + "). Message du patient :\n« " + message.trim() + " »", "elevee", outcome);
                } catch (RuntimeException e) {
                    log.warn("Transmission d'urgence impossible au médecin {} : {}", d.id(), e.getMessage());
                }
            }
            return """
                    Ce que vous décrivez (%s) peut être une urgence.
                    Appelez immédiatement le SAMU au 190 (Protection civile : 198).
                    - Ne restez pas seul(e), prévenez un proche.
                    - Ne prenez pas la route vous-même.%s""".formatted(urgency.get(),
                    outcome.forwardedTo.isEmpty() ? "" : "\nVos médecins ont aussi été prévenus.");
        }

        String text = UrgencyDetector.normalize(message);
        // Transfert depuis la messagerie : seuls les messages cités du patient comptent (pas l'en-tête)
        boolean transfer = text.startsWith("(transfert depuis la messagerie");
        if (transfer) {
            int end = text.indexOf(')'); // fin de l'en-tête (normalize() a remplacé les retours à la ligne)
            text = end < 0 ? "" : text.substring(end + 1);
        }
        return withEmergencyFooter(answer(me, text, transfer));
    }

    /** Toute réponse se termine par la conduite à tenir en cas d'urgence. */
    public static String withEmergencyFooter(String reply) {
        return reply.trim() + "\n\n" + EMERGENCY_FOOTER;
    }

    public static final String EMERGENCY_FOOTER =
            "🚨 En cas d'urgence : appelez le SAMU au 190, ou contactez directement votre médecin (Messages).";

    private String answer(SecurityUser me, String text, boolean transfer) {
        // Symptômes : soins, médicament sans ordonnance adapté au dossier, quand consulter
        Optional<String> advice = advisor.advise(text, toolbox.snapshot(me));
        if (advice.isPresent()) {
            return (transfer ? "Votre médecin est indisponible : je vous réponds en attendant son retour.\n\n" : "")
                    + advice.get();
        }
        if (containsAny(text, "rendez-vous", "rendez vous", "rdv", "consultation")) {
            return """
                    Pour prendre rendez-vous : onglet « Médecins », choisissez un médecin puis un créneau libre.
                    Vos rendez-vous et leur statut sont dans l'onglet « Rendez-vous ».""";
        }
        if (containsAny(text, "ordonnance", "renouvel", "prescription")) {
            return """
                    Pour un renouvellement d'ordonnance, votre médecin doit valider la demande.
                    Utilisez le menu ⋮ → « Laisser un message au médecin » : il le recevra dans sa messagerie.
                    Vos ordonnances sont dans l'onglet « Traitements » (export PDF possible).""";
        }
        if (containsAny(text, "pharmacie", "acheter", "commander", "trouver un medicament", "ou trouver")) {
            return """
                    Pour trouver un médicament : onglet « Pharmacies » ou, depuis une ordonnance, « Trouver en pharmacie ».
                    Vous pouvez le réserver (retrait sur place) ou le commander en ligne (livraison).""";
        }
        if (transfer) {
            return """
                    Votre médecin est indisponible pour le moment : vos messages restent dans sa messagerie et il les \
                    lira à son retour.
                    - Si un autre médecin vous suit, vous pouvez lui écrire depuis « Messages ».
                    - Pour un nouveau rendez-vous : onglet « Médecins ».""";
        }
        return """
                Décrivez-moi ce que vous ressentez (par exemple : fièvre, mal de tête, toux, mal de gorge, diarrhée, \
                nausées, brûlures d'estomac, mal au dos, allergie) : je vous indiquerai les soins, un médicament sans \
                ordonnance adapté et quand consulter.
                Pour une autre question : menu ⋮ → « Laisser un message au médecin ».""";
    }

    private static boolean containsAny(String text, String... words) {
        return List.of(words).stream().anyMatch(text::contains);
    }
}
