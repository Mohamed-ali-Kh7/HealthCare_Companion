package com.healthcare.medicine;

import com.healthcare.common.dto.PageResponse;
import com.healthcare.medicine.dto.MedicineRequest;
import com.healthcare.medicine.dto.MedicineResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

/** Référentiel : lecture pour tous les utilisateurs connectés, écriture réservée à l'admin. */
@RestController
@RequestMapping("/api/medicines")
@RequiredArgsConstructor
public class MedicineController {

    private final MedicineService medicineService;

    @GetMapping
    public PageResponse<MedicineResponse> search(@RequestParam(required = false) String q,
                                                 @PageableDefault(size = 20, sort = "name",
                                                         direction = Sort.Direction.ASC) Pageable pageable) {
        return medicineService.search(q, pageable);
    }

    @GetMapping("/{id}")
    public MedicineResponse getById(@PathVariable Long id) {
        return medicineService.getById(id);
    }

    @PostMapping
    @PreAuthorize("hasRole('ADMIN')")
    @ResponseStatus(HttpStatus.CREATED)
    public MedicineResponse create(@Valid @RequestBody MedicineRequest request) {
        return medicineService.create(request);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public MedicineResponse update(@PathVariable Long id, @Valid @RequestBody MedicineRequest request) {
        return medicineService.update(id, request);
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        medicineService.delete(id);
        return ResponseEntity.noContent().build();
    }
}
