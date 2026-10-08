package com.healthcare.pharmacy;

import com.healthcare.common.exception.ResourceNotFoundException;
import com.healthcare.pharmacy.dto.PharmacyResponse;
import com.healthcare.pharmacy.dto.UpdatePharmacyRequest;
import com.healthcare.user.User;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class PharmacyService {

    static final double DEFAULT_RADIUS_KM = 5.0;
    static final double MAX_RADIUS_KM = 50.0;
    static final int MAX_RESULTS = 50;

    private final PharmacyRepository pharmacyRepository;

    @Transactional
    public Pharmacy createForPharmacist(User user, String name, String address, String phone,
                                        double latitude, double longitude) {
        return pharmacyRepository.save(new Pharmacy(user, name.trim(), address.trim(), phone, latitude, longitude));
    }

    @Transactional(readOnly = true)
    public PharmacyResponse getMine(Long pharmacistUserId) {
        return PharmacyResponse.from(getEntityByUserId(pharmacistUserId));
    }

    @Transactional
    public PharmacyResponse updateMine(Long pharmacistUserId, UpdatePharmacyRequest r) {
        Pharmacy pharmacy = getEntityByUserId(pharmacistUserId);
        pharmacy.setName(r.name().trim());
        pharmacy.setAddress(r.address().trim());
        pharmacy.setPhone(r.phone());
        pharmacy.setLatitude(r.latitude());
        pharmacy.setLongitude(r.longitude());
        pharmacy.setOpeningHours(r.openingHours());
        if (r.onDuty() != null) {
            pharmacy.setOnDuty(r.onDuty());
        }
        return PharmacyResponse.from(pharmacy);
    }

    @Transactional(readOnly = true)
    public PharmacyResponse getById(Long id) {
        return PharmacyResponse.from(getEntity(id));
    }

    /** Pharmacies actives autour d'une position, triées par distance croissante. */
    @Transactional(readOnly = true)
    public List<PharmacyResponse> findNearby(double lat, double lng, Double radiusKm) {
        double radius = normalizeRadius(radiusKm);
        GeoBox box = GeoBox.around(lat, lng, radius);
        List<Object[]> rows = pharmacyRepository.findNearby(
                lat, lng, box.minLat(), box.maxLat(), box.minLng(), box.maxLng(), radius, MAX_RESULTS);

        Map<Long, Pharmacy> byId = loadByIds(rows.stream().map(row -> asLong(row[0])).toList());
        return rows.stream()
                .filter(row -> byId.containsKey(asLong(row[0])))
                .map(row -> PharmacyResponse.from(byId.get(asLong(row[0])), asDouble(row[1])))
                .toList();
    }

    @Transactional(readOnly = true)
    public Map<Long, Pharmacy> loadByIds(List<Long> ids) {
        if (ids.isEmpty()) {
            return Map.of();
        }
        return pharmacyRepository.findByIdIn(ids).stream()
                .collect(Collectors.toMap(Pharmacy::getId, Function.identity()));
    }

    @Transactional(readOnly = true)
    public Pharmacy getEntity(Long id) {
        return pharmacyRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Pharmacie", id));
    }

    @Transactional(readOnly = true)
    public Pharmacy getEntityByUserId(Long userId) {
        return pharmacyRepository.findByUserId(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Profil pharmacie introuvable"));
    }

    @Transactional(readOnly = true)
    public long count() {
        return pharmacyRepository.count();
    }

    static Long asLong(Object value) {
        return ((Number) value).longValue();
    }

    static Double asDouble(Object value) {
        return value == null ? null : ((Number) value).doubleValue();
    }

    static double normalizeRadius(Double radiusKm) {
        if (radiusKm == null || radiusKm <= 0) {
            return DEFAULT_RADIUS_KM;
        }
        return Math.min(radiusKm, MAX_RADIUS_KM);
    }
}
