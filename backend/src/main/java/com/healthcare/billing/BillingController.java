package com.healthcare.billing;

import com.healthcare.billing.dto.BillingDtos.*;
import com.healthcare.security.SecurityUser;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/** Facturation : médecin (/doctor/...) et patient (/my/...). */
@RestController
@RequestMapping("/api/billing")
@RequiredArgsConstructor
public class BillingController {

    private final BillingService service;

    @GetMapping("/acts")
    @PreAuthorize("hasAnyRole('DOCTOR','PATIENT')")
    public List<ActOption> acts() {
        return service.acts();
    }

    // --- Médecin

    @GetMapping("/doctor/to-invoice")
    @PreAuthorize("hasRole('DOCTOR')")
    public List<ToInvoice> toInvoice(@AuthenticationPrincipal SecurityUser me) {
        return service.toInvoice(me.id());
    }

    @GetMapping("/doctor/summary")
    @PreAuthorize("hasRole('DOCTOR')")
    public BillingSummary summary(@AuthenticationPrincipal SecurityUser me) {
        return service.doctorSummary(me.id());
    }

    @GetMapping("/doctor/invoices")
    @PreAuthorize("hasRole('DOCTOR')")
    public List<InvoiceResponse> doctorInvoices(@AuthenticationPrincipal SecurityUser me,
                                                @RequestParam(required = false) InvoiceStatus status) {
        return service.doctorInvoices(me.id(), status);
    }

    @PostMapping("/doctor/invoices")
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasRole('DOCTOR')")
    public InvoiceResponse create(@AuthenticationPrincipal SecurityUser me,
                                  @Valid @RequestBody CreateInvoiceRequest request) {
        return service.create(me.id(), request);
    }

    @PutMapping("/doctor/invoices/{id}/cash")
    @PreAuthorize("hasRole('DOCTOR')")
    public InvoiceResponse markPaidInCash(@AuthenticationPrincipal SecurityUser me, @PathVariable Long id) {
        return service.markPaidInCash(me.id(), id);
    }

    // --- Société d'ambulance conventionnée

    @GetMapping("/company/to-invoice")
    @PreAuthorize("hasRole('AMBULANCE_COMPANY')")
    public List<ToInvoice> transportsToInvoice(@AuthenticationPrincipal SecurityUser me) {
        return service.transportsToInvoice(me.id());
    }

    @GetMapping("/company/summary")
    @PreAuthorize("hasRole('AMBULANCE_COMPANY')")
    public BillingSummary companySummary(@AuthenticationPrincipal SecurityUser me) {
        return service.companySummary(me.id());
    }

    @GetMapping("/company/invoices")
    @PreAuthorize("hasRole('AMBULANCE_COMPANY')")
    public List<InvoiceResponse> companyInvoices(@AuthenticationPrincipal SecurityUser me) {
        return service.companyInvoices(me.id());
    }

    @PostMapping("/company/invoices")
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasRole('AMBULANCE_COMPANY')")
    public InvoiceResponse createForTransport(@AuthenticationPrincipal SecurityUser me,
                                              @Valid @RequestBody CreateInvoiceRequest request) {
        return service.createForTransport(me.id(), request);
    }

    @PutMapping("/company/invoices/{id}/cash")
    @PreAuthorize("hasRole('AMBULANCE_COMPANY')")
    public InvoiceResponse markTransportPaidInCash(@AuthenticationPrincipal SecurityUser me, @PathVariable Long id) {
        return service.markTransportPaidInCash(me.id(), id);
    }

    // --- Patient

    @GetMapping("/my/invoices")
    @PreAuthorize("hasRole('PATIENT')")
    public List<InvoiceResponse> myInvoices(@AuthenticationPrincipal SecurityUser me) {
        return service.myInvoices(me.id());
    }

    @PostMapping("/my/invoices/{id}/pay")
    @PreAuthorize("hasRole('PATIENT')")
    public InvoiceResponse pay(@AuthenticationPrincipal SecurityUser me, @PathVariable Long id,
                               @Valid @RequestBody PayInvoiceRequest request) {
        return service.pay(me.id(), id, request);
    }
}
