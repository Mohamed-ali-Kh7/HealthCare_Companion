package com.healthcare.appointment;

import com.healthcare.appointment.dto.AppointmentResponse;
import com.healthcare.appointment.dto.CreateAppointmentRequest;
import com.healthcare.common.dto.PageResponse;
import com.healthcare.common.exception.BusinessRuleException;
import com.healthcare.common.exception.ResourceNotFoundException;
import com.healthcare.doctor.Doctor;
import com.healthcare.doctor.DoctorAvailability;
import com.healthcare.doctor.DoctorService;
import com.healthcare.patient.Patient;
import com.healthcare.patient.PatientService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.*;

@Service
@RequiredArgsConstructor
public class AppointmentService {

    /** Horizon de réservation : pas de rendez-vous à plus de 3 mois. */
    private static final int MAX_DAYS_AHEAD = 90;

    private final AppointmentRepository appointmentRepository;
    private final PatientService patientService;
    private final DoctorService doctorService;
    private final Clock clock;

    // ---------------------------------------------------------------- Créneaux

    /**
     * Créneaux libres d'un médecin pour une date : plages du planning découpées
     * selon la durée de consultation, moins les créneaux déjà pris et les créneaux passés.
     */
    @Transactional(readOnly = true)
    public List<LocalDateTime> getAvailableSlots(Long doctorId, LocalDate date) {
        Doctor doctor = doctorService.getEntity(doctorId);
        return computeFreeSlots(doctor, date);
    }

    private List<LocalDateTime> computeFreeSlots(Doctor doctor, LocalDate date) {
        LocalDateTime now = LocalDateTime.now(clock);
        if (date.isBefore(now.toLocalDate()) || date.isAfter(now.toLocalDate().plusDays(MAX_DAYS_AHEAD))) {
            return List.of();
        }

        int step = doctor.getConsultationDurationMinutes();
        Set<LocalDateTime> booked = new HashSet<>(appointmentRepository.findBookedDates(
                doctor.getId(), AppointmentStatus.BLOCKING_SLOT,
                date.atStartOfDay(), date.plusDays(1).atStartOfDay()));

        List<LocalDateTime> slots = new ArrayList<>();
        for (DoctorAvailability range : doctorService.getAvailabilityEntities(doctor.getId(), date.getDayOfWeek())) {
            LocalDateTime slot = date.atTime(range.getStartTime());
            LocalDateTime rangeEnd = date.atTime(range.getEndTime());
            while (!slot.plusMinutes(step).isAfter(rangeEnd)) {
                if (slot.isAfter(now) && !booked.contains(slot)) {
                    slots.add(slot);
                }
                slot = slot.plusMinutes(step);
            }
        }
        slots.sort(Comparator.naturalOrder());
        return slots;
    }

    // ---------------------------------------------------------------- Patient

    @Transactional
    public AppointmentResponse create(Long patientUserId, CreateAppointmentRequest request) {
        Patient patient = patientService.getEntityByUserId(patientUserId);
        // Verrou sur le médecin : sérialise les réservations concurrentes sur son planning
        Doctor doctor = doctorService.lockForBooking(request.doctorId());

        if (!doctor.getUser().isEnabled()) {
            throw new BusinessRuleException("DOCTOR_UNAVAILABLE", "Ce médecin n'accepte pas de rendez-vous");
        }

        LocalDateTime requested = request.appointmentDate().withSecond(0).withNano(0);
        if (!computeFreeSlots(doctor, requested.toLocalDate()).contains(requested)) {
            throw new BusinessRuleException("SLOT_UNAVAILABLE",
                    "Ce créneau n'est pas disponible. Choisissez un créneau proposé par le planning du médecin");
        }

        Appointment appointment = appointmentRepository.save(
                new Appointment(patient, doctor, requested, trimToNull(request.reason())));
        return AppointmentResponse.from(appointment);
    }

    @Transactional(readOnly = true)
    public List<AppointmentResponse> getMyAppointments(Long patientUserId) {
        Patient patient = patientService.getEntityByUserId(patientUserId);
        return appointmentRepository.findByPatientIdOrderByAppointmentDateDesc(patient.getId()).stream()
                .map(AppointmentResponse::from)
                .toList();
    }

    @Transactional
    public AppointmentResponse cancel(Long patientUserId, Long appointmentId) {
        Patient patient = patientService.getEntityByUserId(patientUserId);
        Appointment appointment = findDetailed(appointmentId);
        if (!appointment.getPatient().getId().equals(patient.getId())) {
            throw new ResourceNotFoundException("Rendez-vous", appointmentId); // ne révèle pas son existence
        }
        appointment.cancel(LocalDateTime.now(clock));
        return AppointmentResponse.from(appointment);
    }

    // ---------------------------------------------------------------- Médecin

    @Transactional(readOnly = true)
    public List<AppointmentResponse> getDoctorAppointments(Long doctorUserId, AppointmentStatus status,
                                                           LocalDate from, LocalDate to) {
        Doctor doctor = doctorService.getEntityByUserId(doctorUserId);
        return appointmentRepository.findForDoctor(doctor.getId(), status,
                        from == null ? null : from.atStartOfDay(),
                        to == null ? null : to.plusDays(1).atStartOfDay()).stream()
                .map(AppointmentResponse::from)
                .toList();
    }

    @Transactional
    public AppointmentResponse accept(Long doctorUserId, Long appointmentId) {
        Appointment appointment = findOwnedByDoctor(doctorUserId, appointmentId);
        appointment.accept();
        return AppointmentResponse.from(appointment);
    }

    @Transactional
    public AppointmentResponse reject(Long doctorUserId, Long appointmentId, String note) {
        Appointment appointment = findOwnedByDoctor(doctorUserId, appointmentId);
        appointment.reject(trimToNull(note));
        return AppointmentResponse.from(appointment);
    }

    @Transactional
    public AppointmentResponse complete(Long doctorUserId, Long appointmentId, String note) {
        Appointment appointment = findOwnedByDoctor(doctorUserId, appointmentId);
        appointment.complete(trimToNull(note));
        return AppointmentResponse.from(appointment);
    }

    // ---------------------------------------------------------------- Admin

    @Transactional(readOnly = true)
    public PageResponse<AppointmentResponse> findAll(AppointmentStatus status, Pageable pageable) {
        return PageResponse.of(appointmentRepository.findAllByStatus(status, pageable), AppointmentResponse::from);
    }

    @Transactional(readOnly = true)
    public Map<AppointmentStatus, Long> countByStatus() {
        Map<AppointmentStatus, Long> counts = new EnumMap<>(AppointmentStatus.class);
        for (AppointmentStatus status : AppointmentStatus.values()) {
            counts.put(status, appointmentRepository.countByStatus(status));
        }
        return counts;
    }

    // ---------------------------------------------------------------- Statistiques

    @Transactional(readOnly = true)
    public Map<AppointmentStatus, Long> countByStatusForPatient(Long patientId) {
        return toStatusMap(appointmentRepository.countByStatusForPatient(patientId));
    }

    @Transactional(readOnly = true)
    public Map<AppointmentStatus, Long> countByStatusForDoctor(Long doctorId) {
        return toStatusMap(appointmentRepository.countByStatusForDoctor(doctorId));
    }

    /** Médecins consultés : rendez-vous accepté ou terminé. */
    @Transactional(readOnly = true)
    public long countDoctorsOfPatient(Long patientId) {
        return appointmentRepository.countDistinctDoctorsOfPatient(patientId,
                EnumSet.of(AppointmentStatus.ACCEPTED, AppointmentStatus.COMPLETED));
    }

    /** Prochain rendez-vous en attente ou accepté. */
    @Transactional(readOnly = true)
    public Optional<AppointmentResponse> findNextForPatient(Long patientId) {
        return appointmentRepository.findFirstByPatientIdAndStatusInAndAppointmentDateAfterOrderByAppointmentDateAsc(
                        patientId, AppointmentStatus.BLOCKING_SLOT, LocalDateTime.now(clock))
                .map(AppointmentResponse::from);
    }

    /** Charge des prochains jours (rendez-vous en attente ou acceptés), aujourd'hui inclus, jours vides compris. */
    @Transactional(readOnly = true)
    public Map<LocalDate, Long> countUpcomingPerDayForDoctor(Long doctorId, int days) {
        LocalDate today = LocalDate.now(clock);
        Map<LocalDate, Long> perDay = new TreeMap<>();
        for (int i = 0; i < days; i++) {
            perDay.put(today.plusDays(i), 0L);
        }
        appointmentRepository.findBookedDates(doctorId, AppointmentStatus.BLOCKING_SLOT,
                        today.atStartOfDay(), today.plusDays(days).atStartOfDay())
                .forEach(date -> perDay.merge(date.toLocalDate(), 1L, Long::sum));
        return perDay;
    }

    @Transactional(readOnly = true)
    public long countCompletedForDoctorSince(Long doctorId, LocalDate from) {
        return appointmentRepository.countByDoctorIdAndStatusAndAppointmentDateGreaterThanEqual(
                doctorId, AppointmentStatus.COMPLETED, from.atStartOfDay());
    }

    /** Tous les statuts présents (à 0 si absents) : le client n'a pas à gérer de clé manquante. */
    private static Map<AppointmentStatus, Long> toStatusMap(List<Object[]> rows) {
        Map<AppointmentStatus, Long> counts = new EnumMap<>(AppointmentStatus.class);
        for (AppointmentStatus status : AppointmentStatus.values()) {
            counts.put(status, 0L);
        }
        rows.forEach(row -> counts.put((AppointmentStatus) row[0], (Long) row[1]));
        return counts;
    }

    // ---------------------------------------------------------------- Interne

    private Appointment findDetailed(Long id) {
        return appointmentRepository.findWithDetailsById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Rendez-vous", id));
    }

    // ---------------------------------------------------------------- Facturation

    /** Consultations terminées d'un médecin (les plus récentes d'abord) : base de la facturation. */
    @Transactional(readOnly = true)
    public List<Appointment> findCompletedEntitiesForDoctor(Long doctorId) {
        List<Appointment> list = new ArrayList<>(
                appointmentRepository.findForDoctor(doctorId, AppointmentStatus.COMPLETED, null, null));
        Collections.reverse(list);
        return list;
    }

    /** Consultation terminée du médecin connecté, à facturer ; refusée si elle n'est pas terminée. */
    @Transactional(readOnly = true)
    public Appointment getCompletedEntityOwnedByDoctor(Long doctorUserId, Long appointmentId) {
        Appointment appointment = findOwnedByDoctor(doctorUserId, appointmentId);
        if (appointment.getStatus() != AppointmentStatus.COMPLETED) {
            throw new BusinessRuleException("APPOINTMENT_NOT_COMPLETED",
                    "Seule une consultation terminée peut être facturée");
        }
        return appointment;
    }

    private Appointment findOwnedByDoctor(Long doctorUserId, Long appointmentId) {
        Doctor doctor = doctorService.getEntityByUserId(doctorUserId);
        Appointment appointment = findDetailed(appointmentId);
        if (!appointment.getDoctor().getId().equals(doctor.getId())) {
            throw new ResourceNotFoundException("Rendez-vous", appointmentId);
        }
        return appointment;
    }

    private static String trimToNull(String value) {
        return (value == null || value.isBlank()) ? null : value.trim();
    }
}
