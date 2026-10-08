package com.healthcare.pharmacy;

import com.healthcare.common.exception.ResourceNotFoundException;
import com.healthcare.medicine.Medicine;
import com.healthcare.medicine.MedicineService;
import com.healthcare.pharmacy.dto.MedicineAvailabilityResponse;
import com.healthcare.pharmacy.dto.PharmacyResponse;
import com.healthcare.pharmacy.dto.StockRequest;
import com.healthcare.pharmacy.dto.StockResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class StockService {

    private final StockRepository stockRepository;
    private final PharmacyService pharmacyService;
    private final MedicineService medicineService;

    // ---------------------------------------------------------------- Pharmacien

    @Transactional(readOnly = true)
    public List<StockResponse> getMine(Long pharmacistUserId) {
        Pharmacy pharmacy = pharmacyService.getEntityByUserId(pharmacistUserId);
        return stockRepository.findByPharmacyIdOrderByMedicineNameAsc(pharmacy.getId()).stream()
                .map(StockResponse::from)
                .toList();
    }

    /** Upsert : met à jour la ligne existante du médicament, ou la crée. */
    @Transactional
    public StockResponse upsertMine(Long pharmacistUserId, StockRequest request) {
        Pharmacy pharmacy = pharmacyService.getEntityByUserId(pharmacistUserId);
        return StockResponse.from(upsert(pharmacy, request));
    }

    @Transactional
    public List<StockResponse> bulkUpsertMine(Long pharmacistUserId, List<StockRequest> requests) {
        Pharmacy pharmacy = pharmacyService.getEntityByUserId(pharmacistUserId);
        return requests.stream().map(r -> StockResponse.from(upsert(pharmacy, r))).toList();
    }

    @Transactional
    public void deleteMine(Long pharmacistUserId, Long stockId) {
        Pharmacy pharmacy = pharmacyService.getEntityByUserId(pharmacistUserId);
        Stock stock = stockRepository.findWithDetailsById(stockId)
                .orElseThrow(() -> new ResourceNotFoundException("Stock", stockId));
        if (!stock.getPharmacy().getId().equals(pharmacy.getId())) {
            throw new ResourceNotFoundException("Stock", stockId);
        }
        stockRepository.delete(stock);
    }

    private Stock upsert(Pharmacy pharmacy, StockRequest r) {
        Stock stock = stockRepository.findByPharmacyIdAndMedicineId(pharmacy.getId(), r.medicineId())
                .orElseGet(() -> {
                    Medicine medicine = medicineService.getEntity(r.medicineId());
                    return new Stock(pharmacy, medicine, 0, null);
                });
        stock.setQuantity(r.quantity());
        stock.setPrice(r.price());
        return stockRepository.saveAndFlush(stock); // flush : updatedAt renseigné dans la réponse
    }

    // ---------------------------------------------------------------- Patients / médecins

    @Transactional(readOnly = true)
    public List<StockResponse> getStockOfPharmacy(Long pharmacyId) {
        pharmacyService.getEntity(pharmacyId);
        return stockRepository.findByPharmacyIdOrderByMedicineNameAsc(pharmacyId).stream()
                .filter(s -> s.getQuantity() > 0)
                .map(StockResponse::from)
                .toList();
    }

    /** "Où trouver ce médicament près de moi ?" — pharmacies proches qui l'ont en stock. */
    @Transactional(readOnly = true)
    public List<MedicineAvailabilityResponse> findAvailability(Long medicineId, double lat, double lng, Double radiusKm) {
        medicineService.getEntity(medicineId); // 404 si inconnu
        double radius = PharmacyService.normalizeRadius(radiusKm);
        GeoBox box = GeoBox.around(lat, lng, radius);

        List<Object[]> rows = stockRepository.findAvailabilityNearby(
                medicineId, lat, lng, box.minLat(), box.maxLat(), box.minLng(), box.maxLng(),
                radius, PharmacyService.MAX_RESULTS);

        Map<Long, Pharmacy> byId = pharmacyService.loadByIds(
                rows.stream().map(row -> PharmacyService.asLong(row[0])).toList());

        return rows.stream()
                .filter(row -> byId.containsKey(PharmacyService.asLong(row[0])))
                .map(row -> new MedicineAvailabilityResponse(
                        PharmacyResponse.from(byId.get(PharmacyService.asLong(row[0])), PharmacyService.asDouble(row[1])),
                        ((Number) row[2]).intValue(),
                        toBigDecimal(row[3])))
                .toList();
    }

    private static BigDecimal toBigDecimal(Object value) {
        if (value == null) {
            return null;
        }
        return value instanceof BigDecimal bd ? bd : new BigDecimal(value.toString());
    }
}
