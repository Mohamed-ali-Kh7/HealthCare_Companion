package com.healthcare.ambulance;

public enum AmbulanceRequestType {
    /** Urgence vitale : aucune validation, le médecin est seulement informé. */
    EMERGENCY,
    /** Transport sanitaire programmé (dialyse, examen...) : validé par le médecin traitant. */
    SCHEDULED
}
