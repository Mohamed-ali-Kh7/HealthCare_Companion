package com.healthcare.prescription;

import com.healthcare.appointment.CareAccessService;
import com.healthcare.common.exception.ResourceNotFoundException;
import com.healthcare.doctor.Doctor;
import com.healthcare.doctor.DoctorService;
import com.healthcare.medication.MedicationService;
import com.healthcare.medicine.MedicineService;
import com.healthcare.patient.Patient;
import com.healthcare.patient.PatientService;
import com.healthcare.prescription.dto.CreatePrescriptionRequest;
import com.healthcare.prescription.dto.PrescriptionItemRequest;
import com.healthcare.prescription.dto.PrescriptionResponse;
import com.healthcare.security.SecurityUser;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.LocalDate;
import java.util.List;

@Service
@RequiredArgsConstructor
public class PrescriptionService {

    private final PrescriptionRepository prescriptionRepository;
    private final PatientService patientService;
    private final DoctorService doctorService;
    private final MedicineService medicineService;
    private final MedicationService medicationService;
    private final CareAccessService careAccessService;
    private final Clock clock;

    /**
     * Le médecin prescrit pour un patient qu'il suit (rendez-vous accepté ou terminé).
     * Chaque ligne alimente automatiquement le carnet de suivi du patient (rappels).
     */
    @Transactional
    public PrescriptionResponse create(Long doctorUserId, CreatePrescriptionRequest request) {
        Doctor doctor = doctorService.getEntityByUserId(doctorUserId);
        Patient patient = patientService.getEntity(request.patientId());
        careAccessService.assertCanTreatPatient(doctor.getId(), patient.getId());

        LocalDate today = LocalDate.now(clock);
        Prescription prescription = new Prescription(patient, doctor, today, trimToNull(request.notes()));
        for (PrescriptionItemRequest r : request.items()) {
            prescription.addItem(new PrescriptionItem(
                    medicineService.getEntity(r.medicineId()),
                    r.prescribedDosage().trim(),
                    r.timesPerDay(),
                    r.durationDays(),
                    trimToNull(r.instructions())));
        }
        Prescription saved = prescriptionRepository.save(prescription);

        saved.getItems().forEach(item -> medicationService.createFromPrescriptionItem(item, patient, today));
        return PrescriptionResponse.from(saved);
    }

    @Transactional(readOnly = true)
    public List<PrescriptionResponse> getMine(Long patientUserId) {
        Patient patient = patientService.getEntityByUserId(patientUserId);
        return toResponses(prescriptionRepository.findByPatientIdOrderByPrescriptionDateDescIdDesc(patient.getId()));
    }

    @Transactional(readOnly = true)
    public List<PrescriptionResponse> getIssuedByDoctor(Long doctorUserId) {
        Doctor doctor = doctorService.getEntityByUserId(doctorUserId);
        return toResponses(prescriptionRepository.findByDoctorIdOrderByPrescriptionDateDescIdDesc(doctor.getId()));
    }

    /** Historique complet d'un patient suivi (toutes ordonnances, tous médecins). */
    @Transactional(readOnly = true)
    public List<PrescriptionResponse> getPatientHistoryForDoctor(Long doctorUserId, Long patientId) {
        Doctor doctor = doctorService.getEntityByUserId(doctorUserId);
        careAccessService.assertCanViewPatient(doctor.getId(), patientId);
        return toResponses(prescriptionRepository.findByPatientIdOrderByPrescriptionDateDescIdDesc(patientId));
    }

    /** Patient propriétaire, médecin auteur ou admin. Sinon 404 (on ne révèle pas l'existence). */
    @Transactional(readOnly = true)
    public PrescriptionResponse getById(SecurityUser me, Long id) {
        Prescription p = prescriptionRepository.findWithDetailsById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Ordonnance", id));

        boolean allowed = switch (me.role()) {
            case ADMIN -> true;
            case PATIENT -> p.getPatient().getId().equals(patientService.getEntityByUserId(me.id()).getId());
            case DOCTOR -> p.getDoctor().getId().equals(doctorService.getEntityByUserId(me.id()).getId());
            default -> false;
        };
        if (!allowed) {
            throw new ResourceNotFoundException("Ordonnance", id);
        }
        return PrescriptionResponse.from(p);
    }

    private static List<PrescriptionResponse> toResponses(List<Prescription> prescriptions) {
        return prescriptions.stream().map(PrescriptionResponse::from).toList();
    }

    private static String trimToNull(String value) {
        return (value == null || value.isBlank()) ? null : value.trim();
    }
}
