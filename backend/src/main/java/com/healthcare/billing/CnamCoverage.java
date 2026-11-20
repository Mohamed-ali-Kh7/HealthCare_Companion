package com.healthcare.billing;

/**
 * Prise en charge CNAM (simulée : aucune connexion réelle à la CNAM).
 * <ul>
 *   <li>{@link #NONE} : le patient paie tout, pas de remboursement ;</li>
 *   <li>{@link #PRIVATE_SECTOR} : filière privée / tiers payant, le patient ne paie que le ticket modérateur,
 *       la part CNAM est réglée au médecin par la caisse ;</li>
 *   <li>{@link #REIMBURSEMENT} : système de remboursement, le patient paie tout puis dépose le bulletin de soins
 *       pour être remboursé de la part CNAM.</li>
 * </ul>
 */
public enum CnamCoverage {
    NONE("Sans prise en charge"),
    PRIVATE_SECTOR("Filière privée (tiers payant)"),
    REIMBURSEMENT("Système de remboursement");

    private final String label;

    CnamCoverage(String label) {
        this.label = label;
    }

    public String label() {
        return label;
    }
}
