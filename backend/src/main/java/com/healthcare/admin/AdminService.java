package com.healthcare.admin;

import com.healthcare.admin.dto.DashboardResponse;
import com.healthcare.appointment.AppointmentService;
import com.healthcare.medicine.MedicineService;
import com.healthcare.pharmacy.PharmacyService;
import com.healthcare.speciality.SpecialityService;
import com.healthcare.telemonitoring.TelemonitoringService;
import com.healthcare.user.UserService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Duration;

/** Tableau de bord de supervision : agrège les compteurs exposés par chaque module. */
@Service
@RequiredArgsConstructor
public class AdminService {

    private final UserService userService;
    private final AppointmentService appointmentService;
    private final PharmacyService pharmacyService;
    private final MedicineService medicineService;
    private final SpecialityService specialityService;
    private final TelemonitoringService telemonitoringService;
    private final Clock clock;

    @Transactional(readOnly = true)
    public DashboardResponse dashboard() {
        return new DashboardResponse(
                userService.countByRole(),
                userService.countDisabled(),
                appointmentService.countByStatus(),
                pharmacyService.count(),
                medicineService.count(),
                specialityService.count(),
                telemonitoringService.countReceivedSince(clock.instant().minus(Duration.ofHours(24))));
    }
}
