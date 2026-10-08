package com.healthcare.common.dto;

/** Résumé d'une personne (patient ou médecin) embarqué dans d'autres réponses. */
public record PersonSummary(Long id, String firstName, String lastName) {
}
