package com.healthcare.order;

import com.healthcare.order.dto.OrderResponse;

/**
 * Changement sur une commande, à pousser en temps réel à l'autre partie
 * (création → pharmacien ; confirmation, refus, remise → patient ; annulation → pharmacien).
 */
public record OrderEvent(OrderResponse order, Long recipientUserId) {
}
