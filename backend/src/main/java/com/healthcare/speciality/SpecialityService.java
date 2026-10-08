package com.healthcare.speciality;

import com.healthcare.common.exception.ConflictException;
import com.healthcare.common.exception.ResourceNotFoundException;
import com.healthcare.speciality.dto.SpecialityRequest;
import com.healthcare.speciality.dto.SpecialityResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class SpecialityService {

    private final SpecialityRepository specialityRepository;

    @Transactional(readOnly = true)
    public List<SpecialityResponse> findAll() {
        return specialityRepository.findAllByOrderByNameAsc().stream()
                .map(SpecialityResponse::from)
                .toList();
    }

    @Transactional(readOnly = true)
    public SpecialityResponse getById(Long id) {
        return SpecialityResponse.from(getEntity(id));
    }

    @Transactional(readOnly = true)
    public Speciality getEntity(Long id) {
        return specialityRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Spécialité", id));
    }

    @Transactional
    public SpecialityResponse create(SpecialityRequest request) {
        String name = request.name().trim();
        if (specialityRepository.existsByNameIgnoreCase(name)) {
            throw new ConflictException("SPECIALITY_ALREADY_EXISTS", "Cette spécialité existe déjà");
        }
        return SpecialityResponse.from(specialityRepository.save(new Speciality(name, request.description())));
    }

    @Transactional
    public SpecialityResponse update(Long id, SpecialityRequest request) {
        Speciality speciality = getEntity(id);
        String name = request.name().trim();
        if (specialityRepository.existsByNameIgnoreCaseAndIdNot(name, id)) {
            throw new ConflictException("SPECIALITY_ALREADY_EXISTS", "Cette spécialité existe déjà");
        }
        speciality.setName(name);
        speciality.setDescription(request.description());
        return SpecialityResponse.from(speciality);
    }

    /** Refusée si des médecins y sont rattachés (contrainte de clé étrangère). */
    @Transactional
    public void delete(Long id) {
        Speciality speciality = getEntity(id);
        try {
            specialityRepository.delete(speciality);
            specialityRepository.flush();
        } catch (DataIntegrityViolationException e) {
            throw new ConflictException("SPECIALITY_IN_USE",
                    "Impossible de supprimer : des médecins sont rattachés à cette spécialité");
        }
    }

    @Transactional(readOnly = true)
    public long count() {
        return specialityRepository.count();
    }
}
