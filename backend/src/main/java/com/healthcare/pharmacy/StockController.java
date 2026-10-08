package com.healthcare.pharmacy;

import com.healthcare.pharmacy.dto.BulkStockRequest;
import com.healthcare.pharmacy.dto.StockRequest;
import com.healthcare.pharmacy.dto.StockResponse;
import com.healthcare.security.SecurityUser;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/** Gestion de l'inventaire de la pharmacie du pharmacien connecté. */
@RestController
@RequestMapping("/api/pharmacies/me/stocks")
@PreAuthorize("hasRole('PHARMACIST')")
@RequiredArgsConstructor
public class StockController {

    private final StockService stockService;

    @GetMapping
    public List<StockResponse> getMine(@AuthenticationPrincipal SecurityUser me) {
        return stockService.getMine(me.id());
    }

    /** Upsert d'une ligne : {"medicineId":4,"quantity":25,"price":3.450} */
    @PutMapping
    public StockResponse upsert(@AuthenticationPrincipal SecurityUser me,
                                @Valid @RequestBody StockRequest request) {
        return stockService.upsertMine(me.id(), request);
    }

    /** Mise à jour en lot (synchronisation depuis un logiciel externe). */
    @PutMapping("/bulk")
    public List<StockResponse> bulkUpsert(@AuthenticationPrincipal SecurityUser me,
                                          @Valid @RequestBody BulkStockRequest request) {
        return stockService.bulkUpsertMine(me.id(), request.items());
    }

    @DeleteMapping("/{stockId}")
    public ResponseEntity<Void> delete(@PathVariable Long stockId, @AuthenticationPrincipal SecurityUser me) {
        stockService.deleteMine(me.id(), stockId);
        return ResponseEntity.noContent().build();
    }
}
