package com.healthcare.medicine;

import com.healthcare.common.dto.PageResponse;
import com.healthcare.common.exception.ConflictException;
import com.healthcare.common.exception.ResourceNotFoundException;
import com.healthcare.medicine.dto.MedicineRequest;
import com.healthcare.medicine.dto.MedicineResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class MedicineService {

    private final MedicineRepository medicineRepository;

    @Transactional(readOnly = true)
    public PageResponse<MedicineResponse> search(String q, Pageable pageable) {
        String query = (q == null || q.isBlank()) ? null : q.trim();
        return PageResponse.of(medicineRepository.search(query, pageable), MedicineResponse::from);
    }

    @Transactional(readOnly = true)
    public MedicineResponse getById(Long id) {
        return MedicineResponse.from(getEntity(id));
    }

    @Transactional(readOnly = true)
    public Medicine getEntity(Long id) {
        return medicineRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Médicament", id));
    }

    @Transactional
    public MedicineResponse create(MedicineRequest r) {
        if (medicineRepository.existsByNameIgnoreCaseAndStrengthIgnoreCaseAndForm(
                r.name().trim(), r.strength().trim(), r.form())) {
            throw duplicate();
        }
        Medicine medicine = new Medicine(r.name().trim(), r.activeIngredient().trim(), r.form(),
                r.strength().trim(), trimToNull(r.manufacturer()));
        return MedicineResponse.from(medicineRepository.save(medicine));
    }

    @Transactional
    public MedicineResponse update(Long id, MedicineRequest r) {
        Medicine medicine = getEntity(id);
        if (medicineRepository.existsByNameIgnoreCaseAndStrengthIgnoreCaseAndFormAndIdNot(
                r.name().trim(), r.strength().trim(), r.form(), id)) {
            throw duplicate();
        }
        medicine.setName(r.name().trim());
        medicine.setActiveIngredient(r.activeIngredient().trim());
        medicine.setForm(r.form());
        medicine.setStrength(r.strength().trim());
        medicine.setManufacturer(trimToNull(r.manufacturer()));
        return MedicineResponse.from(medicine);
    }

    /** Refusée si le médicament est référencé (ordonnance, stock, carnet). */
    @Transactional
    public void delete(Long id) {
        Medicine medicine = getEntity(id);
        try {
            medicineRepository.delete(medicine);
            medicineRepository.flush();
        } catch (DataIntegrityViolationException e) {
            throw new ConflictException("MEDICINE_IN_USE",
                    "Impossible de supprimer : ce médicament est utilisé (ordonnance, stock ou carnet)");
        }
    }

    @Transactional(readOnly = true)
    public long count() {
        return medicineRepository.count();
    }

    private static ConflictException duplicate() {
        return new ConflictException("MEDICINE_ALREADY_EXISTS",
                "Ce médicament existe déjà avec ce dosage et cette forme");
    }

    private static String trimToNull(String value) {
        return (value == null || value.isBlank()) ? null : value.trim();
    }
}
