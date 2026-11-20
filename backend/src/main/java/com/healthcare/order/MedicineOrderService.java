package com.healthcare.order;

import com.healthcare.common.exception.BusinessRuleException;
import com.healthcare.common.exception.ResourceNotFoundException;
import com.healthcare.medicine.MedicineService;
import com.healthcare.order.dto.CreateOrderRequest;
import com.healthcare.order.dto.OrderResponse;
import com.healthcare.patient.Patient;
import com.healthcare.patient.PatientService;
import com.healthcare.pharmacy.Pharmacy;
import com.healthcare.pharmacy.PharmacyService;
import com.healthcare.pharmacy.Stock;
import com.healthcare.pharmacy.StockService;
import lombok.RequiredArgsConstructor;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

/**
 * Réservations (retrait en pharmacie) et commandes en ligne (livraison, paiement à la livraison).
 * Le stock n'est décompté qu'à la confirmation par la pharmacie : une demande en attente ne bloque rien.
 */
@Service
@RequiredArgsConstructor
public class MedicineOrderService {

    /** Commandes ouvertes simultanées par patient : évite les abus (réservations « par précaution »). */
    private static final int MAX_OPEN_ORDERS = 5;

    private final MedicineOrderRepository repository;
    private final PatientService patientService;
    private final PharmacyService pharmacyService;
    private final MedicineService medicineService;
    private final StockService stockService;
    private final ApplicationEventPublisher events;

    // ---------------------------------------------------------------- Patient

    @Transactional
    public OrderResponse create(Long patientUserId, CreateOrderRequest request) {
        Patient patient = patientService.getEntityByUserId(patientUserId);
        Pharmacy pharmacy = pharmacyService.getEntity(request.pharmacyId());
        Stock stock = stockService.findStock(pharmacy.getId(), request.medicineId())
                .filter(s -> s.getQuantity() > 0)
                .orElseThrow(() -> new BusinessRuleException("OUT_OF_STOCK",
                        "Cette pharmacie n'a plus ce médicament en stock"));
        if (request.quantity() > stock.getQuantity()) {
            throw new BusinessRuleException("INSUFFICIENT_STOCK",
                    "Seulement " + stock.getQuantity() + " disponible(s) dans cette pharmacie");
        }
        if (repository.countByPatientIdAndStatusIn(patient.getId(),
                List.of(OrderStatus.PENDING, OrderStatus.CONFIRMED)) >= MAX_OPEN_ORDERS) {
            throw new BusinessRuleException("TOO_MANY_OPEN_ORDERS",
                    "Vous avez déjà " + MAX_OPEN_ORDERS + " commandes en cours : finalisez-en une d'abord");
        }

        String address = trimToNull(request.deliveryAddress());
        // Sans numéro saisi : celui du profil patient
        String phone = trimToNull(request.phone()) != null ? trimToNull(request.phone()) : patient.getPhone();
        if (request.type() == OrderType.DELIVERY) {
            if (address == null) {
                throw new BusinessRuleException("ADDRESS_REQUIRED", "L'adresse de livraison est obligatoire");
            }
            if (phone == null) {
                throw new BusinessRuleException("PHONE_REQUIRED", "Un numéro de téléphone est obligatoire pour la livraison");
            }
        } else {
            address = null; // retrait en pharmacie
        }

        MedicineOrder order = repository.save(new MedicineOrder(patient, pharmacy,
                medicineService.getEntity(request.medicineId()), request.type(), request.quantity(),
                stock.getPrice(), address, phone, trimToNull(request.note())));
        OrderResponse response = OrderResponse.from(order);
        events.publishEvent(new OrderEvent(response, pharmacy.getUser().getId()));
        return response;
    }

    @Transactional(readOnly = true)
    public List<OrderResponse> getMine(Long patientUserId) {
        Patient patient = patientService.getEntityByUserId(patientUserId);
        return repository.findByPatientIdOrderByCreatedAtDesc(patient.getId()).stream()
                .map(OrderResponse::from)
                .toList();
    }

    @Transactional
    public OrderResponse cancel(Long patientUserId, Long orderId) {
        Patient patient = patientService.getEntityByUserId(patientUserId);
        MedicineOrder order = find(orderId);
        if (!order.getPatient().getId().equals(patient.getId())) {
            throw new ResourceNotFoundException("Commande", orderId); // ne révèle pas son existence
        }
        boolean wasConfirmed = order.getStatus() == OrderStatus.CONFIRMED;
        order.cancel();
        if (wasConfirmed) {
            stockService.restock(order.getPharmacy().getId(), order.getMedicine().getId(), order.getQuantity());
        }
        return notifyAndReturn(order, order.getPharmacy().getUser().getId());
    }

    // ---------------------------------------------------------------- Pharmacien

    @Transactional(readOnly = true)
    public List<OrderResponse> getForPharmacy(Long pharmacistUserId) {
        Pharmacy pharmacy = pharmacyService.getEntityByUserId(pharmacistUserId);
        return repository.findByPharmacyIdOrderByCreatedAtDesc(pharmacy.getId()).stream()
                .map(OrderResponse::from)
                .toList();
    }

    @Transactional
    public OrderResponse confirm(Long pharmacistUserId, Long orderId, String note) {
        MedicineOrder order = findForPharmacist(pharmacistUserId, orderId);
        order.confirm(trimToNull(note));
        stockService.withdraw(order.getPharmacy().getId(), order.getMedicine().getId(), order.getQuantity());
        return notifyAndReturn(order, order.getPatient().getUser().getId());
    }

    @Transactional
    public OrderResponse reject(Long pharmacistUserId, Long orderId, String note) {
        MedicineOrder order = findForPharmacist(pharmacistUserId, orderId);
        order.reject(trimToNull(note));
        return notifyAndReturn(order, order.getPatient().getUser().getId());
    }

    /** Médicament retiré à la pharmacie ou livré. */
    @Transactional
    public OrderResponse complete(Long pharmacistUserId, Long orderId) {
        MedicineOrder order = findForPharmacist(pharmacistUserId, orderId);
        order.complete();
        return notifyAndReturn(order, order.getPatient().getUser().getId());
    }

    // ---------------------------------------------------------------- Interne

    private OrderResponse notifyAndReturn(MedicineOrder order, Long recipientUserId) {
        OrderResponse response = OrderResponse.from(order);
        events.publishEvent(new OrderEvent(response, recipientUserId));
        return response;
    }

    private MedicineOrder find(Long id) {
        return repository.findWithDetailsById(id).orElseThrow(() -> new ResourceNotFoundException("Commande", id));
    }

    private MedicineOrder findForPharmacist(Long pharmacistUserId, Long orderId) {
        Pharmacy pharmacy = pharmacyService.getEntityByUserId(pharmacistUserId);
        MedicineOrder order = find(orderId);
        if (!order.getPharmacy().getId().equals(pharmacy.getId())) {
            throw new ResourceNotFoundException("Commande", orderId);
        }
        return order;
    }

    private static String trimToNull(String value) {
        return (value == null || value.isBlank()) ? null : value.trim();
    }
}
