package com.healthcare.telemonitoring;

/**
 * Types de mesures collectées par le smartphone, avec unité et bornes de plausibilité
 * (une valeur hors bornes est rejetée : capteur défaillant ou donnée falsifiée).
 */
public enum SensorType {
    /** Nombre de pas cumulés sur la période mesurée (podomètre). */
    STEPS("pas", 0, 100_000),
    /** Fréquence cardiaque (saisie manuelle ou objet connecté). */
    HEART_RATE("bpm", 20, 250),
    /** Intensité moyenne d'activité mesurée par l'accéléromètre. */
    ACCELERATION("m/s²", 0, 100);

    private final String unit;
    private final double min;
    private final double max;

    SensorType(String unit, double min, double max) {
        this.unit = unit;
        this.min = min;
        this.max = max;
    }

    public String unit() {
        return unit;
    }

    public boolean accepts(double value) {
        return value >= min && value <= max;
    }
}
