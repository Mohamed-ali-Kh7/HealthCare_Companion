package com.healthcare.appointment;

import java.util.EnumSet;
import java.util.Set;

public enum AppointmentStatus {
    PENDING,
    ACCEPTED,
    REJECTED,
    COMPLETED,
    CANCELLED;

    /** Statuts qui occupent un créneau dans le planning du médecin. */
    public static final Set<AppointmentStatus> BLOCKING_SLOT = EnumSet.of(PENDING, ACCEPTED);
}
