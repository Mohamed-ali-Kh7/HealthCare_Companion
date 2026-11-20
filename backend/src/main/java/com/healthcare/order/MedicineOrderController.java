package com.healthcare.order;

import com.healthcare.order.dto.CreateOrderRequest;
import com.healthcare.order.dto.OrderResponse;
import com.healthcare.order.dto.PharmacistNoteRequest;
import com.healthcare.security.SecurityUser;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/orders")
@RequiredArgsConstructor
public class MedicineOrderController {

    private final MedicineOrderService service;

    // ---------------------------------------------------------------- Patient

    @PostMapping
    @PreAuthorize("hasRole('PATIENT')")
    @ResponseStatus(HttpStatus.CREATED)
    public OrderResponse create(@AuthenticationPrincipal SecurityUser me, @Valid @RequestBody CreateOrderRequest request) {
        return service.create(me.id(), request);
    }

    @GetMapping("/my")
    @PreAuthorize("hasRole('PATIENT')")
    public List<OrderResponse> getMine(@AuthenticationPrincipal SecurityUser me) {
        return service.getMine(me.id());
    }

    @PutMapping("/{id}/cancel")
    @PreAuthorize("hasRole('PATIENT')")
    public OrderResponse cancel(@PathVariable Long id, @AuthenticationPrincipal SecurityUser me) {
        return service.cancel(me.id(), id);
    }

    // ---------------------------------------------------------------- Pharmacien

    @GetMapping("/pharmacy")
    @PreAuthorize("hasRole('PHARMACIST')")
    public List<OrderResponse> getForPharmacy(@AuthenticationPrincipal SecurityUser me) {
        return service.getForPharmacy(me.id());
    }

    @PutMapping("/{id}/confirm")
    @PreAuthorize("hasRole('PHARMACIST')")
    public OrderResponse confirm(@PathVariable Long id, @AuthenticationPrincipal SecurityUser me,
                                 @Valid @RequestBody(required = false) PharmacistNoteRequest body) {
        return service.confirm(me.id(), id, body == null ? null : body.note());
    }

    @PutMapping("/{id}/reject")
    @PreAuthorize("hasRole('PHARMACIST')")
    public OrderResponse reject(@PathVariable Long id, @AuthenticationPrincipal SecurityUser me,
                                @Valid @RequestBody(required = false) PharmacistNoteRequest body) {
        return service.reject(me.id(), id, body == null ? null : body.note());
    }

    @PutMapping("/{id}/complete")
    @PreAuthorize("hasRole('PHARMACIST')")
    public OrderResponse complete(@PathVariable Long id, @AuthenticationPrincipal SecurityUser me) {
        return service.complete(me.id(), id);
    }
}
