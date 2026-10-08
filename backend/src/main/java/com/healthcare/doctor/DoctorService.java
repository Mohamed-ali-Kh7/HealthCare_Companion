package com.healthcare.doctor;

import com.healthcare.common.dto.PageResponse;
import com.healthcare.common.exception.BusinessRuleException;
import com.healthcare.common.exception.ResourceNotFoundException;
import com.healthcare.doctor.dto.AvailabilityRequest;
import com.healthcare.doctor.dto.AvailabilityResponse;
import com.healthcare.doctor.dto.DoctorResponse;
import com.healthcare.doctor.dto.UpdateDoctorRequest;
import com.healthcare.speciality.Speciality;
import com.healthcare.speciality.SpecialityService;
import com.healthcare.user.User;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.DayOfWeek;
import java.time.Duration;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

@Service
@RequiredArgsConstructor
public class DoctorService {

    private static final Comparator<DoctorAvailability> BY_DAY_THEN_TIME =
            Comparator.comparing(DoctorAvailability::getDayOfWeek)
                    .thenComparing(DoctorAvailability::getStartTime);

    private final DoctorRepository doctorRepository;
    private final DoctorAvailabilityRepository availabilityRepository;
    private final SpecialityService specialityService;

    // ---------------------------------------------------------------- Profil

    @Transactional
    public Doctor createProfile(User user, String firstName, String lastName, String phone,
                                Long specialityId, String address) {
        Speciality speciality = specialityService.getEntity(specialityId);
        return doctorRepository.save(new Doctor(user, firstName.trim(), lastName.trim(), phone,
                address.trim(), speciality));
    }

    @Transactional(readOnly = true)
    public PageResponse<DoctorResponse> search(String q, Long specialityId, Pageable pageable) {
        String query = (q == null || q.isBlank()) ? null : q.trim();
        return PageResponse.of(doctorRepository.search(query, specialityId, pageable), DoctorResponse::from);
    }

    @Transactional(readOnly = true)
    public DoctorResponse getById(Long id) {
        return DoctorResponse.from(doctorRepository.findWithDetailsById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Médecin", id)));
    }

    @Transactional(readOnly = true)
    public DoctorResponse getMyProfile(Long userId) {
        return DoctorResponse.from(getEntityByUserId(userId));
    }

    @Transactional
    public DoctorResponse updateMyProfile(Long userId, UpdateDoctorRequest request) {
        Doctor doctor = getEntityByUserId(userId);
        doctor.setFirstName(request.firstName().trim());
        doctor.setLastName(request.lastName().trim());
        doctor.setPhone(request.phone());
        doctor.setAddress(request.address().trim());
        doctor.setBio(request.bio());
        doctor.setConsultationDurationMinutes(request.consultationDurationMinutes());
        if (!doctor.getSpeciality().getId().equals(request.specialityId())) {
            doctor.setSpeciality(specialityService.getEntity(request.specialityId()));
        }
        return DoctorResponse.from(doctor);
    }

    // ---------------------------------------------------------------- Accès entités (autres modules)

    @Transactional(readOnly = true)
    public Doctor getEntity(Long id) {
        return doctorRepository.findWithDetailsById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Médecin", id));
    }

    @Transactional(readOnly = true)
    public Doctor getEntityByUserId(Long userId) {
        return doctorRepository.findByUserId(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Profil médecin introuvable"));
    }

    /** À appeler dans une transaction d'écriture (module rendez-vous). */
    @Transactional
    public Doctor lockForBooking(Long doctorId) {
        return doctorRepository.findByIdForUpdate(doctorId)
                .orElseThrow(() -> new ResourceNotFoundException("Médecin", doctorId));
    }

    // ---------------------------------------------------------------- Planning

    @Transactional(readOnly = true)
    public List<AvailabilityResponse> getAvailabilities(Long doctorId) {
        getEntity(doctorId); // 404 si le médecin n'existe pas
        return availabilityRepository.findByDoctorId(doctorId).stream()
                .sorted(BY_DAY_THEN_TIME)
                .map(AvailabilityResponse::from)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<AvailabilityResponse> getMyAvailabilities(Long userId) {
        return getAvailabilities(getEntityByUserId(userId).getId());
    }

    @Transactional(readOnly = true)
    public List<DoctorAvailability> getAvailabilityEntities(Long doctorId, DayOfWeek day) {
        return availabilityRepository.findByDoctorIdAndDayOfWeek(doctorId, day).stream()
                .sorted(BY_DAY_THEN_TIME)
                .toList();
    }

    /** Remplace tout le planning hebdomadaire (plus simple côté mobile qu'un CRUD ligne par ligne). */
    @Transactional
    public List<AvailabilityResponse> replaceMyAvailabilities(Long userId, List<AvailabilityRequest> requests) {
        Doctor doctor = getEntityByUserId(userId);
        validateAvailabilities(requests, doctor.getConsultationDurationMinutes());

        availabilityRepository.deleteByDoctorId(doctor.getId());
        List<DoctorAvailability> saved = availabilityRepository.saveAll(requests.stream()
                .map(r -> new DoctorAvailability(doctor, r.dayOfWeek(), r.startTime(), r.endTime()))
                .toList());

        return saved.stream().sorted(BY_DAY_THEN_TIME).map(AvailabilityResponse::from).toList();
    }

    private void validateAvailabilities(List<AvailabilityRequest> requests, int durationMinutes) {
        List<AvailabilityRequest> sorted = new ArrayList<>(requests);
        sorted.sort(Comparator.comparing(AvailabilityRequest::dayOfWeek)
                .thenComparing(AvailabilityRequest::startTime));

        for (int i = 0; i < sorted.size(); i++) {
            AvailabilityRequest current = sorted.get(i);
            if (!current.startTime().isBefore(current.endTime())) {
                throw new BusinessRuleException("INVALID_TIME_RANGE",
                        "L'heure de début doit précéder l'heure de fin (" + current.dayOfWeek() + ")");
            }
            if (Duration.between(current.startTime(), current.endTime()).toMinutes() < durationMinutes) {
                throw new BusinessRuleException("RANGE_TOO_SHORT",
                        "Une plage doit contenir au moins une consultation (" + durationMinutes + " min)");
            }
            if (i > 0) {
                AvailabilityRequest previous = sorted.get(i - 1);
                if (previous.dayOfWeek() == current.dayOfWeek()
                        && current.startTime().isBefore(previous.endTime())) {
                    throw new BusinessRuleException("OVERLAPPING_RANGES",
                            "Deux plages se chevauchent le " + current.dayOfWeek());
                }
            }
        }
    }

    @Transactional(readOnly = true)
    public long count() {
        return doctorRepository.count();
    }
}
