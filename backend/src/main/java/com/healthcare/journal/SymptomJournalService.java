package com.healthcare.journal;

import com.healthcare.appointment.CareAccessService;
import com.healthcare.common.exception.BusinessRuleException;
import com.healthcare.common.exception.ResourceNotFoundException;
import com.healthcare.doctor.DoctorService;
import com.healthcare.journal.dto.SymptomEntryRequest;
import com.healthcare.journal.dto.SymptomEntryResponse;
import com.healthcare.patient.Patient;
import com.healthcare.patient.PatientService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.LocalDate;
import java.util.List;

/**
 * Journal de symptômes : le patient note chaque jour douleur, humeur, sommeil et température ;
 * son médecin consulte l'évolution avant la consultation.
 */
@Service
@RequiredArgsConstructor
public class SymptomJournalService {

    /** Rattrapage possible des jours oubliés, dans une limite raisonnable. */
    private static final int MAX_DAYS_BACK = 30;
    private static final int MAX_PERIOD_DAYS = 90;

    private final SymptomEntryRepository repository;
    private final PatientService patientService;
    private final DoctorService doctorService;
    private final CareAccessService careAccessService;
    private final Clock clock;

    // ---------------------------------------------------------------- Patient

    /** Crée ou remplace l'entrée du jour indiqué. */
    @Transactional
    public SymptomEntryResponse save(Long patientUserId, SymptomEntryRequest r) {
        Patient patient = patientService.getEntityByUserId(patientUserId);
        LocalDate today = LocalDate.now(clock);
        if (r.date().isAfter(today)) {
            throw new BusinessRuleException("DATE_IN_FUTURE", "Impossible de remplir le journal pour un jour futur");
        }
        if (r.date().isBefore(today.minusDays(MAX_DAYS_BACK))) {
            throw new BusinessRuleException("DATE_TOO_OLD",
                    "Le journal peut être complété jusqu'à " + MAX_DAYS_BACK + " jours en arrière");
        }
        String note = r.note() == null || r.note().isBlank() ? null : r.note().trim();
        if (r.pain() == null && r.mood() == null && r.sleepHours() == null && r.temperature() == null && note == null) {
            throw new BusinessRuleException("EMPTY_ENTRY", "Renseignez au moins une information");
        }
        SymptomEntry entry = repository.findByPatientIdAndEntryDate(patient.getId(), r.date())
                .orElseGet(() -> new SymptomEntry(patient, r.date()));
        entry.update(r.pain(), r.mood(), r.sleepHours(), r.temperature(), note);
        return SymptomEntryResponse.from(repository.saveAndFlush(entry)); // flush : updatedAt renseigné
    }

    @Transactional(readOnly = true)
    public List<SymptomEntryResponse> getMine(Long patientUserId, int days) {
        Patient patient = patientService.getEntityByUserId(patientUserId);
        return entries(patient.getId(), days);
    }

    @Transactional
    public void deleteMine(Long patientUserId, LocalDate date) {
        Patient patient = patientService.getEntityByUserId(patientUserId);
        SymptomEntry entry = repository.findByPatientIdAndEntryDate(patient.getId(), date)
                .orElseThrow(() -> new ResourceNotFoundException("Entrée du journal", date));
        repository.delete(entry);
    }

    // ---------------------------------------------------------------- Médecin

    /** Médecin ayant un rendez-vous avec le patient (y compris en attente : préparation de la consultation). */
    @Transactional(readOnly = true)
    public List<SymptomEntryResponse> getForDoctor(Long doctorUserId, Long patientId, int days) {
        careAccessService.assertCanViewPatient(doctorService.getEntityByUserId(doctorUserId).getId(), patientId);
        return entries(patientId, days);
    }

    // ---------------------------------------------------------------- Interne

    private List<SymptomEntryResponse> entries(Long patientId, int days) {
        int period = Math.max(1, Math.min(days, MAX_PERIOD_DAYS));
        LocalDate today = LocalDate.now(clock);
        return repository.findByPatientIdAndEntryDateBetweenOrderByEntryDateAsc(patientId,
                        today.minusDays(period - 1L), today).stream()
                .map(SymptomEntryResponse::from)
                .toList();
    }
}
