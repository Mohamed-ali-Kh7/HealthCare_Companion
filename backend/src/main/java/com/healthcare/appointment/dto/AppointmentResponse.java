package com.healthcare.appointment.dto;

import com.healthcare.appointment.Appointment;
import com.healthcare.appointment.AppointmentStatus;
import com.healthcare.common.dto.PersonSummary;
import com.healthcare.doctor.Doctor;
import com.healthcare.patient.Patient;

import java.time.LocalDateTime;

public record AppointmentResponse(
        Long id,
        LocalDateTime appointmentDate,
        AppointmentStatus status,
        String reason,
        String doctorNote,
        PersonSummary patient,
        DoctorSummary doctor
) {
    public record DoctorSummary(Long id, String firstName, String lastName, String specialityName, String address) {
    }

    public static AppointmentResponse from(Appointment a) {
        Patient p = a.getPatient();
        Doctor d = a.getDoctor();
        return new AppointmentResponse(
                a.getId(), a.getAppointmentDate(), a.getStatus(), a.getReason(), a.getDoctorNote(),
                new PersonSummary(p.getId(), p.getFirstName(), p.getLastName()),
                new DoctorSummary(d.getId(), d.getFirstName(), d.getLastName(),
                        d.getSpeciality().getName(), d.getAddress()));
    }
}
