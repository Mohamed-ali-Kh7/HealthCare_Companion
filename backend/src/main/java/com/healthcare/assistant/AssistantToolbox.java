package com.healthcare.assistant;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.healthcare.appointment.AppointmentService;
import com.healthcare.appointment.CareAccessService;
import com.healthcare.assistant.dto.AssistantDtos.DoctorOption;
import com.healthcare.doctor.DoctorService;
import com.healthcare.journal.SymptomJournalService;
import com.healthcare.medication.MedicationService;
import com.healthcare.messaging.Message;
import com.healthcare.messaging.MessagingService;
import com.healthcare.messaging.dto.SendMessageRequest;
import com.healthcare.patient.Patient;
import com.healthcare.patient.PatientService;
import com.healthcare.prescription.PrescriptionService;
import com.healthcare.security.SecurityUser;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.time.Clock;
import java.time.LocalDate;
import java.time.Period;
import java.util.*;

/**
 * Actions de l'assistant pour UN patient (celui du token, jamais un id fourni par le modèle) :
 * lecture de son historique, liste de ses médecins, transmission d'une demande, signalement d'urgence.
 * Utilisé par l'IA (outils) et par le mode de secours.
 */
@Component
@RequiredArgsConstructor
public class AssistantToolbox {

    /** Ce qu'une réponse a déclenché, renvoyé à l'application. */
    public static final class Outcome {
        boolean urgent;
        String urgencyReason;
        final List<String> forwardedTo = new ArrayList<>();
    }

    private final PatientService patientService;
    private final MedicationService medicationService;
    private final PrescriptionService prescriptionService;
    private final SymptomJournalService journalService;
    private final AppointmentService appointmentService;
    private final CareAccessService careAccessService;
    private final DoctorService doctorService;
    private final MessagingService messagingService;
    private final ObjectMapper objectMapper;
    private final Clock clock;

    // ---------------------------------------------------------------- Historique médical

    /**
     * Résumé du dossier, réduit au nécessaire (prénom, âge, pas de nom ni de coordonnées) :
     * c'est ce qui est envoyé au fournisseur d'IA.
     */
    public String medicalHistoryJson(SecurityUser me) {
        Patient p = patientService.getEntityByUserId(me.id());
        LocalDate today = LocalDate.now(clock);
        Map<String, Object> out = new LinkedHashMap<>();

        Map<String, Object> profile = new LinkedHashMap<>();
        profile.put("prenom", p.getFirstName());
        profile.put("age", p.getDateOfBirth() == null ? null : Period.between(p.getDateOfBirth(), today).getYears());
        profile.put("groupeSanguin", p.getBloodGroup());
        profile.put("allergies", p.getAllergies());
        out.put("patient", profile);

        out.put("traitementsEnCours", medicationService.getMine(me.id()).stream()
                .filter(m -> m.active() && m.ongoing())
                .map(m -> Map.of(
                        "medicament", m.medicine().name() + " " + m.medicine().strength(),
                        "posologie", m.actualDosage() + ", " + m.timesPerDay() + " fois/jour",
                        "jusquAu", String.valueOf(m.endDate())))
                .toList());

        out.put("dernieresOrdonnances", prescriptionService.getMine(me.id()).stream().limit(3)
                .map(rx -> Map.of(
                        "date", rx.prescriptionDate().toString(),
                        "medecin", "Dr " + rx.doctor().lastName() + " (" + rx.doctor().specialityName() + ")",
                        "medicaments", rx.items().stream()
                                .map(i -> i.medicine().name() + " " + i.medicine().strength() + " : "
                                        + i.prescribedDosage() + ", " + i.timesPerDay() + " fois/jour pendant "
                                        + i.durationDays() + " jours")
                                .toList()))
                .toList());

        out.put("journalDeSymptomes14Jours", journalService.getMine(me.id(), 14).stream()
                .map(e -> {
                    Map<String, Object> day = new LinkedHashMap<>();
                    day.put("date", e.date().toString());
                    day.put("douleurSur10", e.pain());
                    day.put("humeurSur5", e.mood());
                    day.put("sommeilHeures", e.sleepHours());
                    day.put("temperature", e.temperature());
                    day.put("remarque", e.note());
                    return day;
                })
                .toList());

        out.put("rendezVous", appointmentService.getMyAppointments(me.id()).stream()
                .filter(a -> !a.appointmentDate().toLocalDate().isBefore(today.minusDays(60)))
                .limit(5)
                .map(a -> Map.of(
                        "date", a.appointmentDate().toString(),
                        "statut", a.status().name(),
                        "medecin", "Dr " + a.doctor().lastName() + " (" + a.doctor().specialityName() + ")",
                        "motif", Objects.toString(a.reason(), "")))
                .toList());
        return toJson(out);
    }

    /**
     * Ce dont les conseils du mode de secours ont besoin : âge, allergies, médicaments en cours (noms).
     * @param age null si la date de naissance est inconnue
     */
    public record PatientSnapshot(Integer age, String allergies, List<String> currentMedicines) {
    }

    public PatientSnapshot snapshot(SecurityUser me) {
        Patient p = patientService.getEntityByUserId(me.id());
        Integer age = p.getDateOfBirth() == null ? null : Period.between(p.getDateOfBirth(), LocalDate.now(clock)).getYears();
        List<String> meds = medicationService.getMine(me.id()).stream()
                .filter(m -> m.active() && m.ongoing())
                .map(m -> m.medicine().name() + " " + Objects.toString(m.medicine().activeIngredient(), ""))
                .toList();
        return new PatientSnapshot(age, p.getAllergies(), meds);
    }

    // ---------------------------------------------------------------- Médecins

    /** Médecins avec qui le patient a une relation de soin (rendez-vous). */
    public List<DoctorOption> myDoctors(SecurityUser me) {
        Patient p = patientService.getEntityByUserId(me.id());
        return careAccessService.findDoctorIdsOfPatient(p.getId()).stream()
                .map(doctorService::getEntity)
                .map(d -> new DoctorOption(d.getId(), "Dr " + d.getFirstName() + " " + d.getLastName(),
                        d.getSpeciality().getName()))
                .toList();
    }

    public String myDoctorsJson(SecurityUser me) {
        return toJson(myDoctors(me));
    }

    // ---------------------------------------------------------------- Transmission au médecin

    /**
     * Envoie la demande dans la messagerie patient ↔ médecin (le médecin la voit dans ses conversations).
     * Le médecin doit suivre le patient : un id inventé ou étranger est refusé.
     */
    public String forwardToDoctor(SecurityUser me, Long doctorId, String summary, String urgency, Outcome outcome) {
        Optional<DoctorOption> doctor = myDoctors(me).stream().filter(d -> d.id().equals(doctorId)).findFirst();
        if (doctor.isEmpty()) {
            return "ERREUR : ce médecin ne suit pas le patient. Utilisez list_my_doctors.";
        }
        String level = switch (Objects.toString(urgency, "")) {
            case "elevee" -> "🔴 Priorité élevée";
            case "moyenne" -> "🟠 Priorité moyenne";
            default -> "🟢 Priorité faible";
        };
        String content = "🤖 Transmis par l'assistant santé · " + level + "\n\n" + summary.trim();
        if (content.length() > Message.MAX_LENGTH) {
            content = content.substring(0, Message.MAX_LENGTH - 1) + "…";
        }
        messagingService.send(me, doctorId, new SendMessageRequest(content), false);
        outcome.forwardedTo.add(doctor.get().name());
        return "Transmis à " + doctor.get().name() + ". Le médecin le verra dans sa messagerie.";
    }

    /** Message du patient, mot pour mot, avec une mention indiquant qu'il vient de l'assistant. */
    public DoctorOption leaveMessage(SecurityUser me, Long doctorId, String message) {
        DoctorOption doctor = myDoctors(me).stream().filter(d -> d.id().equals(doctorId)).findFirst()
                .orElseThrow(() -> new com.healthcare.common.exception.BusinessRuleException("NO_CARE_RELATION",
                        "Vous ne pouvez écrire qu'à un médecin qui vous suit"));
        messagingService.send(me, doctorId,
                new SendMessageRequest("✉️ Message laissé via l'assistant santé\n\n" + message.trim()), false);
        return doctor;
    }

    public void reportEmergency(String reason, Outcome outcome) {
        outcome.urgent = true;
        if (outcome.urgencyReason == null) {
            outcome.urgencyReason = reason;
        }
    }

    private String toJson(Object value) {
        try {
            return objectMapper.writeValueAsString(value);
        } catch (JsonProcessingException e) {
            throw new IllegalStateException(e);
        }
    }
}
