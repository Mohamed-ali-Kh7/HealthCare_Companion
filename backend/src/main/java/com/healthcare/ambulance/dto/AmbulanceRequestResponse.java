package com.healthcare.ambulance.dto;

import com.healthcare.ambulance.AmbulanceRequest;
import com.healthcare.ambulance.AmbulanceRequestStatus;
import com.healthcare.ambulance.AmbulanceRequestType;
import com.healthcare.ambulance.MissionStatus;
import com.healthcare.common.dto.PersonSummary;
import com.healthcare.doctor.Doctor;
import com.healthcare.patient.Patient;
import com.healthcare.transport.AmbulanceCompany;
import com.healthcare.transport.AmbulanceVehicle;
import com.healthcare.transport.VehicleType;

import java.time.Instant;
import java.time.LocalDateTime;

public record AmbulanceRequestResponse(
        Long id,
        AmbulanceRequestType type,
        AmbulanceRequestStatus status,
        Double latitude,
        Double longitude,
        String address,
        String reason,
        LocalDateTime scheduledAt,
        String doctorNote,
        Instant createdAt,
        PatientInfo patient,
        PersonSummary doctor,
        Mission mission
) {
    /** Ce dont l'équipe de secours a besoin immédiatement : joindre le patient, groupe sanguin, allergies. */
    public record PatientInfo(Long id, String firstName, String lastName, String phone,
                              String bloodGroup, String allergies) {
    }

    /** Société conventionnée chargée du transport, véhicule affecté et étape en cours (null si non confié). */
    public record Mission(MissionStatus status, String statusLabel, Company company, Vehicle vehicle, String note,
                          Instant updatedAt) {
    }

    public record Company(Long id, String name, String phone, String conventionNumber, String city) {
    }

    public record Vehicle(Long id, String plate, VehicleType type, String typeLabel, String driverName,
                          String driverPhone) {
    }

    public static AmbulanceRequestResponse from(AmbulanceRequest r) {
        Patient p = r.getPatient();
        Doctor d = r.getDoctor();
        return new AmbulanceRequestResponse(
                r.getId(), r.getType(), r.getStatus(), r.getLatitude(), r.getLongitude(), r.getAddress(),
                r.getReason(), r.getScheduledAt(), r.getDoctorNote(), r.getCreatedAt(),
                new PatientInfo(p.getId(), p.getFirstName(), p.getLastName(), p.getPhone(),
                        p.getBloodGroup(), p.getAllergies()),
                d == null ? null : new PersonSummary(d.getId(), d.getFirstName(), d.getLastName()),
                mission(r));
    }

    private static Mission mission(AmbulanceRequest r) {
        if (r.getMissionStatus() == null) {
            return null;
        }
        AmbulanceCompany c = r.getCompany();
        AmbulanceVehicle v = r.getVehicle();
        return new Mission(r.getMissionStatus(), r.getMissionStatus().label(),
                new Company(c.getId(), c.getName(), c.getPhone(), c.getConventionNumber(), c.getCity()),
                v == null ? null : new Vehicle(v.getId(), v.getPlate(), v.getType(), v.getType().label(),
                        v.getDriverName(), v.getDriverPhone()),
                r.getCompanyNote(), r.getMissionUpdatedAt());
    }
}
