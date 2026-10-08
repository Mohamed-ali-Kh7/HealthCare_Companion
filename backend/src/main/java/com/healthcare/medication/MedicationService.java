package com.healthcare.medication;

import com.healthcare.common.exception.BusinessRuleException;
import com.healthcare.common.exception.ResourceNotFoundException;
import com.healthcare.medication.dto.MedicationRequest;
import com.healthcare.medication.dto.MedicationResponse;
import com.healthcare.medicine.Medicine;
import com.healthcare.medicine.MedicineService;
import com.healthcare.patient.Patient;
import com.healthcare.patient.PatientService;
import com.healthcare.prescription.PrescriptionItem;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.List;

@Service
@RequiredArgsConstructor
public class MedicationService {

    private static final LocalTime FIRST_INTAKE = LocalTime.of(8, 0);
    private static final int DAY_SPAN_MINUTES = 12 * 60; // prises réparties entre 08:00 et 20:00

    private final MedicationRepository medicationRepository;
    private final PatientService patientService;
    private final MedicineService medicineService;
    private final Clock clock;

    /** Appelé par le module ordonnance : chaque ligne devient un traitement actif avec rappels. */
    @Transactional
    public void createFromPrescriptionItem(PrescriptionItem item, Patient patient, LocalDate startDate) {
        LocalDate endDate = startDate.plusDays(item.getDurationDays() - 1L);
        medicationRepository.save(new Medication(patient, item.getMedicine(), item,
                item.getPrescribedDosage(), item.getTimesPerDay(), startDate, endDate,
                defaultReminderTimes(item.getTimesPerDay())));
    }

    @Transactional(readOnly = true)
    public List<MedicationResponse> getMine(Long patientUserId) {
        Patient patient = patientService.getEntityByUserId(patientUserId);
        LocalDate today = LocalDate.now(clock);
        return medicationRepository.findByPatientIdOrderByStartDateDesc(patient.getId()).stream()
                .map(m -> MedicationResponse.from(m, today))
                .toList();
    }

    @Transactional
    public MedicationResponse create(Long patientUserId, MedicationRequest r) {
        if (r.medicineId() == null) {
            throw new BusinessRuleException("MEDICINE_REQUIRED", "Le médicament est obligatoire");
        }
        Patient patient = patientService.getEntityByUserId(patientUserId);
        Medicine medicine = medicineService.getEntity(r.medicineId());
        validateDates(r.startDate(), r.endDate());

        Medication medication = new Medication(patient, medicine, null, r.actualDosage().trim(),
                r.timesPerDay(), r.startDate(), r.endDate(), resolveReminderTimes(r));
        if (r.active() != null) {
            medication.setActive(r.active());
        }
        return MedicationResponse.from(medicationRepository.save(medication), LocalDate.now(clock));
    }

    @Transactional
    public MedicationResponse update(Long patientUserId, Long id, MedicationRequest r) {
        Medication medication = findOwned(patientUserId, id);
        validateDates(r.startDate(), r.endDate());

        medication.setActualDosage(r.actualDosage().trim());
        medication.setTimesPerDay(r.timesPerDay());
        medication.setStartDate(r.startDate());
        medication.setEndDate(r.endDate());
        medication.replaceReminderTimes(resolveReminderTimes(r));
        if (r.active() != null) {
            medication.setActive(r.active());
        }
        return MedicationResponse.from(medication, LocalDate.now(clock));
    }

    @Transactional
    public void delete(Long patientUserId, Long id) {
        medicationRepository.delete(findOwned(patientUserId, id));
    }

    // ---------------------------------------------------------------- Interne

    private Medication findOwned(Long patientUserId, Long id) {
        Patient patient = patientService.getEntityByUserId(patientUserId);
        Medication medication = medicationRepository.findWithDetailsById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Traitement", id));
        if (!medication.getPatient().getId().equals(patient.getId())) {
            throw new ResourceNotFoundException("Traitement", id);
        }
        return medication;
    }

    private static void validateDates(LocalDate start, LocalDate end) {
        if (end != null && end.isBefore(start)) {
            throw new BusinessRuleException("INVALID_DATE_RANGE", "La date de fin précède la date de début");
        }
    }

    private static List<LocalTime> resolveReminderTimes(MedicationRequest r) {
        if (r.reminderTimes() == null || r.reminderTimes().isEmpty()) {
            return defaultReminderTimes(r.timesPerDay());
        }
        if (r.reminderTimes().size() != r.timesPerDay()) {
            throw new BusinessRuleException("REMINDER_COUNT_MISMATCH",
                    "Le nombre d'heures de rappel doit être égal au nombre de prises par jour");
        }
        return r.reminderTimes().stream().sorted().distinct().toList();
    }

    /** 1 → 08:00 ; 2 → 08:00, 20:00 ; 3 → 08:00, 14:00, 20:00 ; 4 → 08:00, 12:00, 16:00, 20:00 ... */
    static List<LocalTime> defaultReminderTimes(int timesPerDay) {
        List<LocalTime> times = new ArrayList<>();
        if (timesPerDay <= 1) {
            times.add(FIRST_INTAKE);
            return times;
        }
        int interval = DAY_SPAN_MINUTES / (timesPerDay - 1);
        for (int i = 0; i < timesPerDay; i++) {
            times.add(FIRST_INTAKE.plusMinutes((long) i * interval));
        }
        return times;
    }
}
