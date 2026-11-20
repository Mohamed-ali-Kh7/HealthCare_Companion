package com.healthcare.transport.dto;

import com.healthcare.transport.AmbulanceCompany;
import com.healthcare.transport.AmbulanceVehicle;
import com.healthcare.transport.VehicleType;
import jakarta.validation.constraints.*;

public final class TransportDtos {

    private TransportDtos() {
    }

    /**
     * Société vue par le patient (distance, véhicules en service) ou par elle-même.
     * {@code distanceKm} et {@code vehiclesInService} : null quand ils ne sont pas calculés.
     */
    public record CompanyResponse(Long id, String name, String conventionNumber, String address, String city,
                                  String phone, double latitude, double longitude, int serviceRadiusKm,
                                  boolean acceptingRequests, Double distanceKm, Long vehiclesInService) {
        public static CompanyResponse from(AmbulanceCompany c, Double distanceKm, Long vehiclesInService) {
            return new CompanyResponse(c.getId(), c.getName(), c.getConventionNumber(), c.getAddress(), c.getCity(),
                    c.getPhone(), c.getLatitude(), c.getLongitude(), c.getServiceRadiusKm(), c.isAcceptingRequests(),
                    distanceKm, vehiclesInService);
        }
    }

    public record UpdateCompanyRequest(
            @NotBlank @Size(max = 120) String name,
            @NotBlank @Size(max = 255) String address,
            @NotBlank @Size(max = 80) String city,
            @NotBlank @Size(max = 30) @Pattern(regexp = "^[+0-9 ]*$", message = "Numéro de téléphone invalide") String phone,
            @NotNull @DecimalMin("-90.0") @DecimalMax("90.0") Double latitude,
            @NotNull @DecimalMin("-180.0") @DecimalMax("180.0") Double longitude,
            @NotNull @Min(1) @Max(200) Integer serviceRadiusKm,
            @NotNull Boolean acceptingRequests) {
    }

    public record VehicleRequest(
            @NotBlank @Size(max = 20) String plate,
            @NotNull VehicleType type,
            @Size(max = 80) String driverName,
            @Size(max = 30) @Pattern(regexp = "^[+0-9 ]*$", message = "Numéro de téléphone invalide") String driverPhone) {
    }

    public record VehicleResponse(Long id, String plate, VehicleType type, String typeLabel, String driverName,
                                  String driverPhone, boolean inService) {
        public static VehicleResponse from(AmbulanceVehicle v) {
            return new VehicleResponse(v.getId(), v.getPlate(), v.getType(), v.getType().label(), v.getDriverName(),
                    v.getDriverPhone(), v.isInService());
        }
    }

    public record InServiceRequest(@NotNull Boolean inService) {
    }
}
