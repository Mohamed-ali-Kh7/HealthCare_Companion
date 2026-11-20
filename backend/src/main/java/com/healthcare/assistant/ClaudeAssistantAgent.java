package com.healthcare.assistant;

import com.anthropic.client.AnthropicClient;
import com.anthropic.client.okhttp.AnthropicOkHttpClient;
import com.anthropic.core.JsonValue;
import com.anthropic.errors.AnthropicException;
import com.anthropic.models.messages.*;
import com.fasterxml.jackson.core.type.TypeReference;
import com.healthcare.security.SecurityUser;
import jakarta.annotation.PreDestroy;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import java.time.Clock;
import java.time.Duration;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.*;

/**
 * Agent conversationnel (API Claude d'Anthropic) avec outils : historique médical du patient, liste de ses
 * médecins, transmission d'une demande au médecin, signalement d'urgence.
 * Renvoie vide en cas d'indisponibilité : le service bascule alors sur le mode de secours.
 */
@Slf4j
@Component
public class ClaudeAssistantAgent {

    /** Garde-fou : nombre maximal d'allers-retours outils par message du patient. */
    private static final int MAX_TOOL_ROUNDS = 6;

    /**
     * Consignes fixes (mises en cache côté API) : aucune donnée variable ici, la date est envoyée à part.
     */
    static final String SYSTEM_PROMPT = """
            Tu es « l'assistant santé » de l'application HealthCare Companion (Tunisie). Tu réponds aux patients \
            24 h/24, en particulier quand leur médecin n'est pas disponible. Tu apportes une aide de premier niveau : \
            informations médicales générales, réponses aux questions fréquentes, recueil des symptômes et orientation. \
            Tu ne remplaces jamais le médecin : tu ne poses pas de diagnostic, tu ne prescris pas et tu ne modifies \
            jamais un traitement prescrit (ne conseille jamais de l'arrêter ou d'en changer la dose).

            Dossier du patient
            - Pour toute question de santé, consulte d'abord get_medical_history (allergies, traitements en cours, \
            ordonnances, journal de symptômes, rendez-vous) et tiens-en compte. N'invente aucune donnée du dossier.

            Conseils et médicaments (symptômes courants : fièvre, maux de tête, rhume, toux, mal de gorge, diarrhée, \
            nausées, brûlures d'estomac, douleurs musculaires, allergie saisonnière…)
            - Réponds selon les symptômes avec cette structure courte :
              « 🛌 Repos et soins » (repos, hydratation, gestes simples),
              « 💊 Médicament sans ordonnance » (nom, dose usuelle adulte, intervalle et maximum par jour, \
            ex. paracétamol 500 mg à 1 g par prise, 4 à 6 h entre les prises, 3 g par jour au maximum),
              « 🩺 Consultez votre médecin si » (signes d'alerte et durée au-delà de laquelle consulter).
            - Uniquement des médicaments vendus sans ordonnance. Jamais d'antibiotique, de corticoïde, d'anxiolytique \
            ni d'autre médicament sur ordonnance : pour cela, oriente vers le médecin.
            - Avant de proposer un médicament, vérifie dans get_medical_history les allergies (ex. aspirine ou \
            anti-inflammatoires → pas d'ibuprofène), les traitements en cours (anticoagulant → pas d'ibuprofène) et \
            l'âge (enfant : pas de dose adulte, dose selon le poids avec le pharmacien ; après 65 ans : prudence avec \
            les anti-inflammatoires). En cas de doute (grossesse, maladie chronique), conseille d'abord l'avis du \
            pharmacien ou du médecin. Rappelle de lire la notice.
            - Termine toujours par : « 🚨 En cas d'urgence : appelez le SAMU au 190, ou contactez directement votre \
            médecin. »

            Urgences (priorité absolue)
            - Signes d'alerte vitale (douleur thoracique, difficulté à respirer, perte de connaissance, signes d'AVC, \
            convulsions, hémorragie, réaction allergique grave, intoxication, idées suicidaires, fièvre très élevée chez \
            un nourrisson, traumatisme grave…) : appelle report_emergency, puis dis clairement et en premier \
            d'appeler immédiatement le SAMU au 190 (Protection civile : 198). Reste bref, donne au plus deux ou trois \
            gestes simples en attendant les secours. Tu peux aussi transmettre au médecin avec la priorité « elevee ».
            - Si un message système signale un possible signe d'alerte, évalue-le : en cas de doute, traite-le comme \
            une urgence.

            Recueil des symptômes et orientation
            - Pose une ou deux questions ciblées à la fois : depuis quand, intensité de 0 à 10, localisation, fièvre \
            (température), ce qui aggrave ou soulage, autres symptômes, traitements déjà pris.
            - Conclus par une orientation claire, parmi : appeler le 190 maintenant ; consulter un médecin rapidement \
            (sous 24 à 48 h) ; conseils et surveillance, avec les signes qui doivent faire reconsulter.

            Transmission au médecin
            - Si la demande nécessite le médecin (aggravation, symptômes qui durent, question sur son traitement, \
            renouvellement d'ordonnance, résultat d'examen, demande explicite), propose de transmettre au médecin qui \
            le suit (list_my_doctors). Après l'accord du patient, appelle forward_to_doctor avec un résumé clinique \
            structuré : motif, symptômes et durée, intensité, éléments utiles du dossier, question du patient.
            - Si le patient n'a aucun médecin, conseille de prendre rendez-vous depuis l'onglet Médecins.
            - Le patient peut aussi laisser lui-même un message à son médecin depuis le menu de cette conversation.
            - Un message qui commence par « (Transfert depuis la messagerie : … est absent …) » vient d'un patient \
            dont le médecin est indisponible : réponds aux messages cités. Ne transmets pas à ce médecin absent, sauf \
            urgence ; si un autre médecin suit le patient (list_my_doctors), propose plutôt celui-là.

            Style
            - Français simple, chaleureux, phrases courtes, vouvoiement. Réponses courtes (en général moins de 200 mots), \
            adaptées à un écran de téléphone : pas de titres Markdown (#), des tirets et les rubriques à emoji ci-dessus.
            - Si la question sort du domaine de la santé, recentre poliment.
            """;

    private final AssistantProperties properties;
    private final AssistantToolbox toolbox;
    private final Clock clock;
    private final AnthropicClient client;

    public ClaudeAssistantAgent(AssistantProperties properties, AssistantToolbox toolbox, Clock clock) {
        this.properties = properties;
        this.toolbox = toolbox;
        this.clock = clock;
        if (properties.aiEnabled()) {
            AnthropicOkHttpClient.Builder clientBuilder = AnthropicOkHttpClient.builder()
                    .apiKey(properties.apiKey())
                    .timeout(Duration.ofSeconds(90))
                    .maxRetries(2);
            if (properties.baseUrl() != null && !properties.baseUrl().isBlank()) {
                clientBuilder.baseUrl(properties.baseUrl());
            }
            this.client = clientBuilder.build();
        } else {
            this.client = null;
        }
        log.info("Assistant santé : {}", properties.aiEnabled()
                ? "IA activée (modèle " + properties.model() + ")" : "mode de secours (aucune clé ANTHROPIC_API_KEY)");
    }

    @PreDestroy
    void close() {
        if (client != null) {
            client.close();
        }
    }

    public boolean available() {
        return client != null;
    }

    /**
     * @param history          messages précédents (ordre chronologique), sans le message courant
     * @param detectedUrgency  signe d'alerte repéré par le filtre déterministe, s'il y en a un
     */
    public Optional<String> reply(SecurityUser me, List<AssistantMessage> history, String userMessage,
                                  Optional<String> detectedUrgency, AssistantToolbox.Outcome outcome) {
        if (client == null) {
            return Optional.empty();
        }
        MessageCreateParams.Builder builder = MessageCreateParams.builder()
                .model(properties.model())
                .maxTokens(16000L)
                .outputConfig(OutputConfig.builder().effort(OutputConfig.Effort.MEDIUM).build())
                .systemOfTextBlockParams(List.of(
                        TextBlockParam.builder()
                                .text(SYSTEM_PROMPT)
                                .cacheControl(CacheControlEphemeral.builder().build())
                                .build(),
                        // Variable : après le point de cache
                        TextBlockParam.builder()
                                .text("Date du jour : " + LocalDate.now(clock)
                                        .format(DateTimeFormatter.ofPattern("EEEE d MMMM yyyy", Locale.FRENCH)))
                                .build()));
        tools().forEach(builder::addTool);
        if (properties.serverFallbacks()) {
            // Si le modèle refuse une demande (filtres de sécurité), l'API la rejoue sur un autre modèle
            builder.putAdditionalHeader("anthropic-beta", "server-side-fallback-2026-07-01")
                    .putAdditionalBodyProperty("fallbacks", JsonValue.from("default"));
        }

        // Historique : alternance stricte utilisateur / assistant, en commençant par l'utilisateur
        boolean expectUser = true;
        for (AssistantMessage m : history) {
            boolean isUser = m.getRole() == AssistantMessage.Role.USER;
            if (isUser != expectUser) {
                continue;
            }
            if (isUser) {
                builder.addUserMessage(m.getContent());
            } else {
                builder.addAssistantMessage(m.getContent());
            }
            expectUser = !expectUser;
        }
        if (!expectUser) {
            builder.addAssistantMessage("(réponse précédente indisponible)");
        }
        builder.addUserMessage(userMessage);
        detectedUrgency.ifPresent(reason -> builder.addMessage(MessageParam.ofSystem(
                "Le filtre de sécurité de l'application a repéré un possible signe d'alerte dans ce message : « "
                        + reason + " ». Évalue-le en priorité.")));

        try {
            MessageCreateParams params = builder.build();
            for (int round = 0; round <= MAX_TOOL_ROUNDS; round++) {
                Message response = client.messages().create(params);
                StopReason stop = response.stopReason().orElse(StopReason.END_TURN);
                log.debug("Assistant : tour {} stop={} tokens in={} out={} cache={}", round, stop,
                        response.usage().inputTokens(), response.usage().outputTokens(),
                        response.usage().cacheReadInputTokens().orElse(0L));

                if (stop.equals(StopReason.REFUSAL)) {
                    log.warn("Assistant : demande refusée par le modèle");
                    return Optional.empty();
                }
                if (!stop.equals(StopReason.TOOL_USE)) {
                    String text = response.content().stream()
                            .flatMap(b -> b.text().stream())
                            .map(TextBlock::text)
                            .reduce("", (a, b) -> a.isEmpty() ? b : a + "\n\n" + b)
                            .trim();
                    return text.isEmpty() ? Optional.empty() : Optional.of(text);
                }

                List<ContentBlockParam> results = new ArrayList<>();
                for (ContentBlock block : response.content()) {
                    block.toolUse().ifPresent(use -> results.add(ContentBlockParam.ofToolResult(
                            runTool(me, use, outcome))));
                }
                // Réponse complète (y compris la réflexion) renvoyée telle quelle, puis tous les résultats ensemble
                params = params.toBuilder()
                        .addMessage(response)
                        .addUserMessageOfContentBlockParams(results)
                        .build();
            }
            log.warn("Assistant : trop d'appels d'outils, abandon");
            return Optional.empty();
        } catch (AnthropicException e) {
            log.error("Assistant : API Claude indisponible ({}), mode de secours", e.getMessage());
            return Optional.empty();
        }
    }

    // ---------------------------------------------------------------- Outils

    private ToolResultBlockParam runTool(SecurityUser me, ToolUseBlock use, AssistantToolbox.Outcome outcome) {
        ToolResultBlockParam.Builder result = ToolResultBlockParam.builder().toolUseId(use.id());
        try {
            Map<String, Object> input = use._input().convert(new TypeReference<Map<String, Object>>() {
            });
            if (input == null) {
                input = Map.of();
            }
            String content = switch (use.name()) {
                case "get_medical_history" -> toolbox.medicalHistoryJson(me);
                case "list_my_doctors" -> toolbox.myDoctorsJson(me);
                case "forward_to_doctor" -> toolbox.forwardToDoctor(me,
                        ((Number) input.get("doctor_id")).longValue(),
                        String.valueOf(input.get("summary")),
                        String.valueOf(input.get("urgency")),
                        outcome);
                case "report_emergency" -> {
                    toolbox.reportEmergency(String.valueOf(input.get("reason")), outcome);
                    yield "Urgence signalée : l'application affiche au patient les boutons d'appel au SAMU (190) "
                            + "et d'alerte de ses médecins.";
                }
                default -> throw new IllegalArgumentException("Outil inconnu : " + use.name());
            };
            return result.content(content).build();
        } catch (RuntimeException e) {
            log.warn("Assistant : outil {} en échec : {}", use.name(), e.getMessage());
            return result.content("ERREUR : " + e.getMessage()).isError(true).build();
        }
    }

    static List<Tool> tools() {
        return List.of(
                tool("get_medical_history",
                        "Dossier médical du patient connecté : prénom, âge, groupe sanguin, allergies, traitements en "
                                + "cours, 3 dernières ordonnances, journal de symptômes des 14 derniers jours, rendez-vous "
                                + "récents et à venir. À consulter avant de répondre à une question de santé.",
                        Map.of(), List.of()),
                tool("list_my_doctors",
                        "Médecins qui suivent le patient (id, nom, spécialité). Nécessaire avant forward_to_doctor.",
                        Map.of(), List.of()),
                tool("forward_to_doctor",
                        "Transmet une demande au médecin dans la messagerie de l'application, après accord du patient "
                                + "(sauf urgence). Le médecin répondra au patient directement.",
                        Map.of(
                                "doctor_id", Map.of("type", "integer", "description", "id renvoyé par list_my_doctors"),
                                "summary", Map.of("type", "string", "description",
                                        "Résumé clinique en français pour le médecin : motif, symptômes et durée, "
                                                + "intensité, éléments du dossier utiles, question du patient"),
                                "urgency", Map.of("type", "string", "enum", List.of("faible", "moyenne", "elevee"))),
                        List.of("doctor_id", "summary", "urgency")),
                tool("report_emergency",
                        "Signale une situation potentiellement urgente : l'application affiche aussitôt au patient "
                                + "les boutons « Appeler le SAMU (190) » et « Alerter mes médecins ».",
                        Map.of("reason", Map.of("type", "string", "description", "Signe d'alerte en quelques mots")),
                        List.of("reason")));
    }

    private static Tool tool(String name, String description, Map<String, Object> properties, List<String> required) {
        Tool.InputSchema.Properties.Builder props = Tool.InputSchema.Properties.builder();
        properties.forEach((k, v) -> props.putAdditionalProperty(k, JsonValue.from(v)));
        return Tool.builder()
                .name(name)
                .description(description)
                .strict(true)
                .inputSchema(Tool.InputSchema.builder()
                        .properties(props.build())
                        .required(required)
                        .putAdditionalProperty("additionalProperties", JsonValue.from(false))
                        .build())
                .build();
    }
}
