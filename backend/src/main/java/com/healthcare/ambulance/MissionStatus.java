package com.healthcare.ambulance;

/**
 * Exécution d'un transport programmé validé par une société d'ambulance conventionnée.
 * REQUESTED → ACCEPTED (véhicule affecté) | REFUSED (le patient choisit une autre société) ;
 * ACCEPTED → EN_ROUTE → ON_SITE → IN_TRANSIT → ARRIVED (la demande est alors clôturée).
 */
public enum MissionStatus {
    REQUESTED("Demande envoyée à la société"),
    REFUSED("Refusée par la société"),
    ACCEPTED("Acceptée, véhicule affecté"),
    EN_ROUTE("Ambulance en route"),
    ON_SITE("Ambulance sur place"),
    IN_TRANSIT("Transport en cours"),
    ARRIVED("Arrivé à destination");

    private final String label;

    MissionStatus(String label) {
        this.label = label;
    }

    public String label() {
        return label;
    }

    /** Étape suivante du trajet, ou null s'il n'y en a pas. */
    public MissionStatus next() {
        return switch (this) {
            case ACCEPTED -> EN_ROUTE;
            case EN_ROUTE -> ON_SITE;
            case ON_SITE -> IN_TRANSIT;
            case IN_TRANSIT -> ARRIVED;
            default -> null;
        };
    }

    /** Le véhicule est parti : la demande ne peut plus être annulée ni confiée à une autre société. */
    public boolean started() {
        return this == EN_ROUTE || this == ON_SITE || this == IN_TRANSIT || this == ARRIVED;
    }

    /**
     * La société s'est engagée (véhicule affecté) et le trajet n'est pas terminé : c'est elle qui clôture le
     * transport à l'arrivée, sinon il ne pourrait plus être facturé.
     */
    public boolean inProgress() {
        return this == ACCEPTED || this == EN_ROUTE || this == ON_SITE || this == IN_TRANSIT;
    }
}
