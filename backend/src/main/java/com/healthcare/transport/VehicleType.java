package com.healthcare.transport;

public enum VehicleType {
    /** Ambulance : patient allongé, surveillance pendant le trajet. */
    AMBULANCE("Ambulance"),
    /** Véhicule sanitaire léger : patient assis (dialyse, consultation...). */
    VSL("Véhicule sanitaire léger (VSL)");

    private final String label;

    VehicleType(String label) {
        this.label = label;
    }

    public String label() {
        return label;
    }
}
