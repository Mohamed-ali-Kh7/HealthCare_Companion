package com.healthcare.ambulance;

import com.healthcare.ambulance.dto.AmbulanceRequestResponse;

import java.util.List;

/**
 * Mission d'ambulance conventionnée créée ou mise à jour (demande, acceptation, étape du trajet) :
 * poussée en temps réel au patient, au médecin et à la société concernés (message {@code transport_mission}).
 */
public record TransportMissionEvent(AmbulanceRequestResponse request, List<Long> recipientUserIds) {
}
