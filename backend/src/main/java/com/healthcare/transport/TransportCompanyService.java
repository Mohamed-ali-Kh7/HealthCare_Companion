package com.healthcare.transport;

import com.healthcare.common.exception.BusinessRuleException;
import com.healthcare.common.exception.ConflictException;
import com.healthcare.common.exception.ResourceNotFoundException;
import com.healthcare.transport.dto.TransportDtos.*;
import com.healthcare.user.User;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;

/** Sociétés d'ambulance conventionnées : profil, flotte, recherche de proximité. */
@Service
@RequiredArgsConstructor
public class TransportCompanyService {

    private static final double KM_PER_DEGREE = 111.0;
    private static final double DEFAULT_RADIUS_KM = 40;

    private final AmbulanceCompanyRepository companyRepository;
    private final AmbulanceVehicleRepository vehicleRepository;

    @Transactional
    public AmbulanceCompany createForUser(User user, String name, String conventionNumber, String address, String city,
                                          String phone, double latitude, double longitude) {
        return companyRepository.save(new AmbulanceCompany(user, name.trim(), conventionNumber.trim(), address.trim(),
                city.trim(), phone, latitude, longitude));
    }

    // ---------------------------------------------------------------- Patient

    /**
     * Sociétés actives autour du point, les plus proches d'abord. Une société n'apparaît que si le point est dans
     * son rayon d'intervention et qu'elle a au moins un véhicule en service.
     */
    @Transactional(readOnly = true)
    public List<CompanyResponse> findNearby(double lat, double lng, Double radiusKm) {
        double radius = radiusKm == null ? DEFAULT_RADIUS_KM : Math.min(Math.max(radiusKm, 1), 200);
        double dLat = radius / KM_PER_DEGREE;
        double dLng = radius / (KM_PER_DEGREE * Math.max(Math.cos(Math.toRadians(lat)), 0.01));
        List<AmbulanceCompany> candidates = companyRepository.findActiveInBox(lat - dLat, lat + dLat, lng - dLng, lng + dLng);
        if (candidates.isEmpty()) {
            return List.of();
        }
        Map<Long, Long> inService = new HashMap<>();
        vehicleRepository.countInServiceByCompany(candidates.stream().map(AmbulanceCompany::getId).toList())
                .forEach(row -> inService.put((Long) row[0], (Long) row[1]));
        return candidates.stream()
                .map(c -> Map.entry(c, haversineKm(lat, lng, c.getLatitude(), c.getLongitude())))
                .filter(e -> e.getValue() <= radius && e.getValue() <= e.getKey().getServiceRadiusKm())
                .filter(e -> inService.getOrDefault(e.getKey().getId(), 0L) > 0)
                .sorted(Map.Entry.comparingByValue())
                .map(e -> CompanyResponse.from(e.getKey(), Math.round(e.getValue() * 10) / 10.0,
                        inService.get(e.getKey().getId())))
                .toList();
    }

    // ---------------------------------------------------------------- Société

    @Transactional(readOnly = true)
    public CompanyResponse getMine(Long userId) {
        AmbulanceCompany c = getEntityByUserId(userId);
        return CompanyResponse.from(c, null, countInService(c.getId()));
    }

    @Transactional
    public CompanyResponse updateMine(Long userId, UpdateCompanyRequest r) {
        AmbulanceCompany c = getEntityByUserId(userId);
        c.setName(r.name().trim());
        c.setAddress(r.address().trim());
        c.setCity(r.city().trim());
        c.setPhone(r.phone().trim());
        c.setLatitude(r.latitude());
        c.setLongitude(r.longitude());
        c.setServiceRadiusKm(r.serviceRadiusKm());
        c.setAcceptingRequests(r.acceptingRequests());
        return CompanyResponse.from(c, null, countInService(c.getId()));
    }

    @Transactional(readOnly = true)
    public List<VehicleResponse> myVehicles(Long userId) {
        AmbulanceCompany c = getEntityByUserId(userId);
        return vehicleRepository.findByCompanyIdOrderByPlateAsc(c.getId()).stream().map(VehicleResponse::from).toList();
    }

    @Transactional
    public VehicleResponse addVehicle(Long userId, VehicleRequest r) {
        AmbulanceCompany c = getEntityByUserId(userId);
        String plate = normalizePlate(r.plate());
        if (vehicleRepository.existsByPlateIgnoreCase(plate)) {
            throw new ConflictException("PLATE_EXISTS", "Un véhicule avec cette immatriculation existe déjà");
        }
        return VehicleResponse.from(vehicleRepository.save(
                new AmbulanceVehicle(c, plate, r.type(), blankToNull(r.driverName()), blankToNull(r.driverPhone()))));
    }

    @Transactional
    public VehicleResponse updateVehicle(Long userId, Long vehicleId, VehicleRequest r) {
        AmbulanceVehicle v = getOwnedVehicle(userId, vehicleId);
        String plate = normalizePlate(r.plate());
        if (!plate.equalsIgnoreCase(v.getPlate()) && vehicleRepository.existsByPlateIgnoreCase(plate)) {
            throw new ConflictException("PLATE_EXISTS", "Un véhicule avec cette immatriculation existe déjà");
        }
        v.setPlate(plate);
        v.setType(r.type());
        v.setDriverName(blankToNull(r.driverName()));
        v.setDriverPhone(blankToNull(r.driverPhone()));
        return VehicleResponse.from(v);
    }

    @Transactional
    public VehicleResponse setInService(Long userId, Long vehicleId, boolean inService) {
        AmbulanceVehicle v = getOwnedVehicle(userId, vehicleId);
        v.setInService(inService);
        return VehicleResponse.from(v);
    }

    // ---------------------------------------------------------------- Pour les autres modules

    public AmbulanceCompany getEntity(Long id) {
        return companyRepository.findById(id).orElseThrow(() -> new ResourceNotFoundException("Société d'ambulance", id));
    }

    public AmbulanceCompany getEntityByUserId(Long userId) {
        return companyRepository.findByUserId(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Aucune société d'ambulance pour ce compte"));
    }

    /** Véhicule de la société connectée, en service : sinon la mission ne peut pas lui être confiée. */
    public AmbulanceVehicle getVehicleForMission(Long companyUserId, Long vehicleId) {
        AmbulanceVehicle v = getOwnedVehicle(companyUserId, vehicleId);
        if (!v.isInService()) {
            throw new BusinessRuleException("VEHICLE_OUT_OF_SERVICE", "Ce véhicule n'est pas en service");
        }
        return v;
    }

    public long count() {
        return companyRepository.count();
    }

    private AmbulanceVehicle getOwnedVehicle(Long userId, Long vehicleId) {
        AmbulanceCompany c = getEntityByUserId(userId);
        return vehicleRepository.findById(vehicleId)
                .filter(v -> v.getCompany().getId().equals(c.getId()))
                .orElseThrow(() -> new ResourceNotFoundException("Véhicule", vehicleId));
    }

    private long countInService(Long companyId) {
        return vehicleRepository.countInServiceByCompany(List.of(companyId)).stream()
                .mapToLong(row -> (Long) row[1]).sum();
    }

    static double haversineKm(double lat1, double lng1, double lat2, double lng2) {
        double dLat = Math.toRadians(lat2 - lat1);
        double dLng = Math.toRadians(lng2 - lng1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2) + Math.cos(Math.toRadians(lat1))
                * Math.cos(Math.toRadians(lat2)) * Math.sin(dLng / 2) * Math.sin(dLng / 2);
        return 6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    }

    private static String normalizePlate(String plate) {
        return plate.trim().replaceAll("\\s+", " ").toUpperCase(Locale.ROOT);
    }

    private static String blankToNull(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }
}
