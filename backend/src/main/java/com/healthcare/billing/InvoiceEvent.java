package com.healthcare.billing;

import com.healthcare.billing.dto.BillingDtos.InvoiceResponse;

/** Facture émise (→ patient) ou réglée (→ médecin) : poussée en temps réel (message {@code invoice_update}). */
public record InvoiceEvent(InvoiceResponse invoice, Long recipientUserId, String kind) {
}
