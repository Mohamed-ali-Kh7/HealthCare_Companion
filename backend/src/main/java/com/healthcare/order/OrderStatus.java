package com.healthcare.order;

/**
 * PENDING → CONFIRMED | REJECTED | CANCELLED ; CONFIRMED → COMPLETED | CANCELLED.
 * Le stock de la pharmacie est décompté à la confirmation (CONFIRMED) et rendu si la commande
 * confirmée est ensuite annulée.
 */
public enum OrderStatus {
    /** Envoyée, en attente de la pharmacie. */
    PENDING,
    /** Acceptée : médicament mis de côté (réservation) ou en préparation / livraison (commande). */
    CONFIRMED,
    /** Retirée à la pharmacie ou livrée. */
    COMPLETED,
    REJECTED,
    CANCELLED
}
