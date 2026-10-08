package com.healthcare.telemonitoring.dto;

import java.time.LocalDate;

/**
 * Agrégat journalier pour les graphiques du tableau de bord.
 * Pour STEPS, "sum" est le total de la journée ; pour HEART_RATE, "avg/min/max" sont pertinents.
 */
public record DailySummaryResponse(LocalDate date, long count, double min, double max, double avg, double sum) {
}
