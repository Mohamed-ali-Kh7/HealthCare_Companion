package com.healthcare.ambulance;

import com.healthcare.ambulance.dto.AmbulanceRequestResponse;

import java.util.List;

/**
 * Urgence déclenchée par un patient : publiée après l'enregistrement, pour prévenir en temps réel
 * les médecins qui le suivent (comptes utilisateurs listés dans {@code doctorUserIds}).
 */
public record EmergencyRaisedEvent(AmbulanceRequestResponse request, List<Long> doctorUserIds) {
}
