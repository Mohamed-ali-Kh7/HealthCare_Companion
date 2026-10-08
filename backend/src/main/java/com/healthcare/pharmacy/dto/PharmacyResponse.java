package com.healthcare.pharmacy.dto;

import com.healthcare.pharmacy.Pharmacy;

/** distanceKm n'est renseigné que pour les recherches de proximité. */
public record PharmacyResponse(
        Long id,
        String name,
        String address,
        String phone,
        double latitude,
        double longitude,
        String openingHours,
        boolean onDuty,
        Double distanceKm
) {
    public static PharmacyResponse from(Pharmacy p) {
        return from(p, null);
    }

    public static PharmacyResponse from(Pharmacy p, Double distanceKm) {
        Double rounded = distanceKm == null ? null : Math.round(distanceKm * 100.0) / 100.0;
        return new PharmacyResponse(p.getId(), p.getName(), p.getAddress(), p.getPhone(),
                p.getLatitude(), p.getLongitude(), p.getOpeningHours(), p.isOnDuty(), rounded);
    }
}
