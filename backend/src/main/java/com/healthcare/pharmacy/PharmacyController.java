package com.healthcare.pharmacy;

import com.healthcare.pharmacy.dto.MedicineAvailabilityResponse;
import com.healthcare.pharmacy.dto.PharmacyResponse;
import com.healthcare.pharmacy.dto.StockResponse;
import com.healthcare.pharmacy.dto.UpdatePharmacyRequest;
import com.healthcare.security.SecurityUser;
import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/pharmacies")
@RequiredArgsConstructor
public class PharmacyController {

    private final PharmacyService pharmacyService;
    private final StockService stockService;

    /** /api/pharmacies/nearby?lat=36.80&lng=10.18&radiusKm=5 */
    @GetMapping("/nearby")
    public List<PharmacyResponse> findNearby(@RequestParam @DecimalMin("-90") @DecimalMax("90") double lat,
                                             @RequestParam @DecimalMin("-180") @DecimalMax("180") double lng,
                                             @RequestParam(required = false) Double radiusKm) {
        return pharmacyService.findNearby(lat, lng, radiusKm);
    }

    /** /api/pharmacies/availability?medicineId=4&lat=36.80&lng=10.18&radiusKm=10 */
    @GetMapping("/availability")
    public List<MedicineAvailabilityResponse> findAvailability(
            @RequestParam Long medicineId,
            @RequestParam @DecimalMin("-90") @DecimalMax("90") double lat,
            @RequestParam @DecimalMin("-180") @DecimalMax("180") double lng,
            @RequestParam(required = false) Double radiusKm) {
        return stockService.findAvailability(medicineId, lat, lng, radiusKm);
    }

    @GetMapping("/me")
    @PreAuthorize("hasRole('PHARMACIST')")
    public PharmacyResponse getMine(@AuthenticationPrincipal SecurityUser me) {
        return pharmacyService.getMine(me.id());
    }

    @PutMapping("/me")
    @PreAuthorize("hasRole('PHARMACIST')")
    public PharmacyResponse updateMine(@AuthenticationPrincipal SecurityUser me,
                                       @Valid @RequestBody UpdatePharmacyRequest request) {
        return pharmacyService.updateMine(me.id(), request);
    }

    @GetMapping("/{id}")
    public PharmacyResponse getById(@PathVariable Long id) {
        return pharmacyService.getById(id);
    }

    /** Médicaments disponibles (quantité > 0) dans une pharmacie. */
    @GetMapping("/{id}/stocks")
    public List<StockResponse> getStock(@PathVariable Long id) {
        return stockService.getStockOfPharmacy(id);
    }
}
