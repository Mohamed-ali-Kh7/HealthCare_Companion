package com.healthcare.admin.dto;

import com.healthcare.appointment.AppointmentStatus;
import com.healthcare.user.Role;

import java.util.Map;

public record DashboardResponse(
        Map<Role, Long> usersByRole,
        long pendingOrDisabledAccounts,
        Map<AppointmentStatus, Long> appointmentsByStatus,
        long pharmacies,
        long medicines,
        long specialities,
        long sensorReadingsLast24h
) {
}
