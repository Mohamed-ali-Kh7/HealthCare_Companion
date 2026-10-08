package com.healthcare.pharmacy;

/**
 * Rectangle englobant un cercle de rayon donné autour d'un point (pré-filtre indexable).
 * 1° de latitude ≈ 111 km ; 1° de longitude ≈ 111 km × cos(latitude).
 */
record GeoBox(double minLat, double maxLat, double minLng, double maxLng) {

    private static final double KM_PER_DEGREE = 111.0;

    static GeoBox around(double lat, double lng, double radiusKm) {
        double dLat = radiusKm / KM_PER_DEGREE;
        double cos = Math.max(Math.cos(Math.toRadians(lat)), 0.01); // évite la division par ~0 aux pôles
        double dLng = radiusKm / (KM_PER_DEGREE * cos);
        return new GeoBox(lat - dLat, lat + dLat, lng - dLng, lng + dLng);
    }
}
