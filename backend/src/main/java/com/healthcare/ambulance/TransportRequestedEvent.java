package com.healthcare.ambulance;

import com.healthcare.ambulance.dto.AmbulanceRequestResponse;

/**
 * Transport programmé demandé par un patient : publié après l'enregistrement, pour prévenir en temps réel
 * le médecin qui doit le valider (compte utilisateur {@code doctorUserId}).
 */
public record TransportRequestedEvent(AmbulanceRequestResponse request, Long doctorUserId) {
}
