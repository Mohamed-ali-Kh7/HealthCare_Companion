package com.healthcare.telemonitoring.dto;

/** accepted : nouvelles mesures enregistrées ; duplicates : déjà reçues (renvoi) et ignorées. */
public record SensorBatchResult(int accepted, int duplicates) {
}
