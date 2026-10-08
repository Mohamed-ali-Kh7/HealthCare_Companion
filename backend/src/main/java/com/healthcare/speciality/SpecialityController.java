package com.healthcare.speciality;

import com.healthcare.speciality.dto.SpecialityRequest;
import com.healthcare.speciality.dto.SpecialityResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/specialities")
@RequiredArgsConstructor
public class SpecialityController {

    private final SpecialityService specialityService;

    /** Public : nécessaire au formulaire d'inscription des médecins. */
    @GetMapping
    public List<SpecialityResponse> findAll() {
        return specialityService.findAll();
    }

    @GetMapping("/{id}")
    public SpecialityResponse getById(@PathVariable Long id) {
        return specialityService.getById(id);
    }

    @PostMapping
    @PreAuthorize("hasRole('ADMIN')")
    @ResponseStatus(HttpStatus.CREATED)
    public SpecialityResponse create(@Valid @RequestBody SpecialityRequest request) {
        return specialityService.create(request);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public SpecialityResponse update(@PathVariable Long id, @Valid @RequestBody SpecialityRequest request) {
        return specialityService.update(id, request);
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        specialityService.delete(id);
        return ResponseEntity.noContent().build();
    }
}
