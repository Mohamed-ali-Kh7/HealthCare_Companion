package com.healthcare.billing;

import java.math.BigDecimal;

/** Actes facturables, avec un tarif proposé (en dinars) que le médecin ou la société peut modifier. */
public enum CareAct {
    CONSULTATION("Consultation de médecine générale", "45.000"),
    SPECIALIST_CONSULTATION("Consultation de spécialiste", "70.000"),
    FOLLOW_UP("Consultation de contrôle", "30.000"),
    TELECONSULTATION("Téléconsultation", "40.000"),
    HOME_VISIT("Visite à domicile", "80.000"),
    // Transports sanitaires (sociétés d'ambulance conventionnées)
    AMBULANCE_TRANSPORT("Transport en ambulance", "60.000"),
    VSL_TRANSPORT("Transport en véhicule sanitaire léger (VSL)", "35.000");

    private final String label;
    private final BigDecimal suggestedFee;

    CareAct(String label, String suggestedFee) {
        this.label = label;
        this.suggestedFee = new BigDecimal(suggestedFee);
    }

    public String label() {
        return label;
    }

    public BigDecimal suggestedFee() {
        return suggestedFee;
    }

    /** Acte de transport : facturable seulement par une société d'ambulance (et inversement). */
    public boolean isTransport() {
        return this == AMBULANCE_TRANSPORT || this == VSL_TRANSPORT;
    }
}
