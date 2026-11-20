package com.healthcare.order;

public enum OrderType {
    /** Réservation : le patient retire et paie le médicament à la pharmacie. */
    RESERVATION,
    /** Commande en ligne : livraison à l'adresse indiquée, paiement à la livraison. */
    DELIVERY
}
