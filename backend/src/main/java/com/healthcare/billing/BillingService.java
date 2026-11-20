package com.healthcare.billing;

import com.healthcare.ambulance.AmbulanceRequest;
import com.healthcare.ambulance.AmbulanceRequestService;
import com.healthcare.appointment.Appointment;
import com.healthcare.appointment.AppointmentService;
import com.healthcare.billing.dto.BillingDtos.*;
import com.healthcare.billing.payment.PaymentGateway;
import com.healthcare.billing.payment.PaymentGateway.CardPayment;
import com.healthcare.billing.payment.PaymentGateway.PaymentResult;
import com.healthcare.common.exception.BusinessRuleException;
import com.healthcare.common.exception.ConflictException;
import com.healthcare.common.exception.ResourceNotFoundException;
import com.healthcare.doctor.Doctor;
import com.healthcare.doctor.DoctorService;
import com.healthcare.patient.Patient;
import com.healthcare.patient.PatientService;
import com.healthcare.transport.AmbulanceCompany;
import com.healthcare.transport.TransportCompanyService;
import com.healthcare.transport.VehicleType;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.*;
import java.util.Arrays;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.function.Function;
import java.util.function.Predicate;

/**
 * Facturation :
 * - le médecin facture ses consultations terminées ;
 * - la société d'ambulance conventionnée facture ses transports terminés ;
 * - le patient paie en ligne (passerelle simulée) ou sur place (l'émetteur encaisse en espèces).
 * Prise en charge CNAM simulée.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class BillingService {

    private final InvoiceRepository repository;
    private final AppointmentService appointmentService;
    private final AmbulanceRequestService ambulanceRequestService;
    private final PatientService patientService;
    private final DoctorService doctorService;
    private final TransportCompanyService transportCompanyService;
    private final PaymentGateway paymentGateway;
    private final InvoiceVerifier verifier;
    private final BillingProperties properties;
    private final ApplicationEventPublisher events;
    private final Clock clock;

    public List<ActOption> acts() {
        return Arrays.stream(CareAct.values()).map(a -> new ActOption(a, a.label(), a.suggestedFee())).toList();
    }

    // ---------------------------------------------------------------- Médecin

    @Transactional(readOnly = true)
    public List<ToInvoice> toInvoice(Long doctorUserId) {
        Doctor doctor = doctorService.getEntityByUserId(doctorUserId);
        List<Appointment> completed = appointmentService.findCompletedEntitiesForDoctor(doctor.getId());
        if (completed.isEmpty()) {
            return List.of();
        }
        Set<Long> invoiced = repository.findInvoicedAppointmentIds(completed.stream().map(Appointment::getId).toList());
        CareAct act = suggestedAct(doctor);
        return completed.stream().filter(a -> !invoiced.contains(a.getId()))
                .map(a -> new ToInvoice(a.getId(), null, a.getAppointmentDate(), a.getReason(),
                        PatientInfo.from(a.getPatient()), act, act.suggestedFee()))
                .toList();
    }

    @Transactional
    public InvoiceResponse create(Long doctorUserId, CreateInvoiceRequest request) {
        if (request.appointmentId() == null) {
            throw new BusinessRuleException("APPOINTMENT_REQUIRED", "Choisissez la consultation à facturer");
        }
        if (request.act().isTransport()) {
            throw new BusinessRuleException("INVALID_ACT", "Un transport est facturé par la société d'ambulance");
        }
        Appointment appointment = appointmentService.getCompletedEntityOwnedByDoctor(doctorUserId, request.appointmentId());
        if (repository.existsByAppointmentId(appointment.getId())) {
            throw new ConflictException("INVOICE_EXISTS", "Cette consultation est déjà facturée");
        }
        String cnam = requireCnamIfCovered(appointment.getPatient(), request.coverage());
        Invoice invoice = repository.save(new Invoice(nextNumber(), appointment, request.act(), request.amount(),
                request.coverage(), cnam, properties.cnamRatePercent()));
        return issued(invoice);
    }

    @Transactional(readOnly = true)
    public List<InvoiceResponse> doctorInvoices(Long doctorUserId, InvoiceStatus status) {
        Doctor doctor = doctorService.getEntityByUserId(doctorUserId);
        return repository.findByDoctorIdOrderByIdDesc(doctor.getId()).stream()
                .filter(i -> status == null || i.getStatus() == status)
                .map(this::toResponse).toList();
    }

    @Transactional(readOnly = true)
    public BillingSummary doctorSummary(Long doctorUserId) {
        Doctor doctor = doctorService.getEntityByUserId(doctorUserId);
        return summary(repository.findByDoctorIdOrderByIdDesc(doctor.getId()), toInvoice(doctorUserId).size());
    }

    /** Le patient a payé au cabinet : le médecin enregistre l'encaissement en espèces. */
    @Transactional
    public InvoiceResponse markPaidInCash(Long doctorUserId, Long invoiceId) {
        Doctor doctor = doctorService.getEntityByUserId(doctorUserId);
        Invoice invoice = repository.findById(invoiceId)
                .filter(i -> i.getDoctor() != null && i.getDoctor().getId().equals(doctor.getId()))
                .orElseThrow(() -> new ResourceNotFoundException("Facture", invoiceId));
        return paidInCash(invoice);
    }

    // ---------------------------------------------------------------- Société d'ambulance

    @Transactional(readOnly = true)
    public List<ToInvoice> transportsToInvoice(Long companyUserId) {
        AmbulanceCompany company = transportCompanyService.getEntityByUserId(companyUserId);
        List<AmbulanceRequest> arrived = ambulanceRequestService.findArrivedEntitiesForCompany(company.getId());
        if (arrived.isEmpty()) {
            return List.of();
        }
        Set<Long> invoiced = repository.findInvoicedAmbulanceRequestIds(
                arrived.stream().map(AmbulanceRequest::getId).toList());
        return arrived.stream().filter(r -> !invoiced.contains(r.getId()))
                .map(r -> {
                    CareAct act = r.getVehicle() != null && r.getVehicle().getType() == VehicleType.VSL
                            ? CareAct.VSL_TRANSPORT : CareAct.AMBULANCE_TRANSPORT;
                    return new ToInvoice(null, r.getId(), r.getScheduledAt(), r.getReason(),
                            PatientInfo.from(r.getPatient()), act, act.suggestedFee());
                })
                .toList();
    }

    @Transactional
    public InvoiceResponse createForTransport(Long companyUserId, CreateInvoiceRequest request) {
        if (request.ambulanceRequestId() == null) {
            throw new BusinessRuleException("TRANSPORT_REQUIRED", "Choisissez le transport à facturer");
        }
        if (!request.act().isTransport()) {
            throw new BusinessRuleException("INVALID_ACT", "Choisissez un acte de transport (ambulance ou VSL)");
        }
        AmbulanceRequest transport = ambulanceRequestService.getArrivedEntityForCompany(companyUserId,
                request.ambulanceRequestId());
        if (repository.existsByAmbulanceRequestId(transport.getId())) {
            throw new ConflictException("INVOICE_EXISTS", "Ce transport est déjà facturé");
        }
        String cnam = requireCnamIfCovered(transport.getPatient(), request.coverage());
        Invoice invoice = repository.save(Invoice.forTransport(nextNumber(), transport, request.act(), request.amount(),
                request.coverage(), cnam, properties.cnamRatePercent()));
        return issued(invoice);
    }

    @Transactional(readOnly = true)
    public List<InvoiceResponse> companyInvoices(Long companyUserId) {
        AmbulanceCompany company = transportCompanyService.getEntityByUserId(companyUserId);
        return repository.findByCompanyIdOrderByIdDesc(company.getId()).stream().map(this::toResponse).toList();
    }

    @Transactional(readOnly = true)
    public BillingSummary companySummary(Long companyUserId) {
        AmbulanceCompany company = transportCompanyService.getEntityByUserId(companyUserId);
        return summary(repository.findByCompanyIdOrderByIdDesc(company.getId()), transportsToInvoice(companyUserId).size());
    }

    @Transactional
    public InvoiceResponse markTransportPaidInCash(Long companyUserId, Long invoiceId) {
        AmbulanceCompany company = transportCompanyService.getEntityByUserId(companyUserId);
        Invoice invoice = repository.findById(invoiceId)
                .filter(i -> i.getCompany() != null && i.getCompany().getId().equals(company.getId()))
                .orElseThrow(() -> new ResourceNotFoundException("Facture", invoiceId));
        return paidInCash(invoice);
    }

    // ---------------------------------------------------------------- Patient

    @Transactional(readOnly = true)
    public List<InvoiceResponse> myInvoices(Long patientUserId) {
        Patient patient = patientService.getEntityByUserId(patientUserId);
        return repository.findByPatientIdOrderByIdDesc(patient.getId()).stream().map(this::toResponse).toList();
    }

    /** Paiement en ligne par carte (passerelle simulée). Refus de la banque → 422 avec le motif. */
    @Transactional
    public InvoiceResponse pay(Long patientUserId, Long invoiceId, PayInvoiceRequest request) {
        Patient patient = patientService.getEntityByUserId(patientUserId);
        Invoice invoice = repository.findById(invoiceId)
                .filter(i -> i.getPatient().getId().equals(patient.getId()))
                .orElseThrow(() -> new ResourceNotFoundException("Facture", invoiceId));
        if (invoice.getStatus() == InvoiceStatus.PAID) {
            throw new BusinessRuleException("INVOICE_ALREADY_PAID", "Cette facture est déjà réglée");
        }
        PaymentResult result = paymentGateway.charge(new CardPayment(invoice.getPatientDue(),
                "Facture " + invoice.getNumber(), request.holder(), request.cardNumber(), request.expiry(), request.cvv()));
        if (!result.approved()) {
            log.info("Paiement refusé pour la facture {} : {}", invoice.getNumber(), result.errorCode());
            throw new BusinessRuleException("PAYMENT_" + result.errorCode(), result.message());
        }
        invoice.markPaid(PaymentMethod.CARD, result.reference(), result.cardLast4(), Instant.now(clock));
        InvoiceResponse response = toResponse(invoice);
        events.publishEvent(new InvoiceEvent(response, issuerUserId(invoice), "paid"));
        return response;
    }

    // ---------------------------------------------------------------- Vérification publique (QR code)

    @Transactional(readOnly = true)
    public Optional<InvoiceResponse> verifyPublic(String token) {
        return verifier.verify(token).flatMap(repository::findById).map(this::toResponse);
    }

    // ---------------------------------------------------------------- Utilitaires

    private InvoiceResponse issued(Invoice invoice) {
        InvoiceResponse response = toResponse(invoice);
        events.publishEvent(new InvoiceEvent(response, invoice.getPatient().getUser().getId(), "issued"));
        return response;
    }

    private InvoiceResponse paidInCash(Invoice invoice) {
        invoice.markPaid(PaymentMethod.CASH, null, null, Instant.now(clock));
        InvoiceResponse response = toResponse(invoice);
        events.publishEvent(new InvoiceEvent(response, invoice.getPatient().getUser().getId(), "paid"));
        return response;
    }

    private static Long issuerUserId(Invoice invoice) {
        return invoice.getCompany() != null ? invoice.getCompany().getUser().getId()
                : invoice.getDoctor().getUser().getId();
    }

    private static String requireCnamIfCovered(Patient patient, CnamCoverage coverage) {
        String cnam = patient.getCnamNumber();
        if (coverage != CnamCoverage.NONE && (cnam == null || cnam.isBlank())) {
            throw new BusinessRuleException("CNAM_NUMBER_MISSING",
                    "Le patient n'a pas renseigné son numéro CNAM : choisissez « Sans prise en charge » "
                            + "ou demandez-lui de compléter son profil");
        }
        return cnam;
    }

    private BillingSummary summary(List<Invoice> invoices, long toInvoiceCount) {
        ZoneId zone = clock.getZone();
        LocalDate today = LocalDate.now(clock);
        Instant startOfDay = today.atStartOfDay(zone).toInstant();
        Instant startOfMonth = today.withDayOfMonth(1).atStartOfDay(zone).toInstant();

        Predicate<Invoice> paid = i -> i.getStatus() == InvoiceStatus.PAID;
        BigDecimal collectedToday = sum(invoices, paid.and(i -> !i.getPaidAt().isBefore(startOfDay)), Invoice::getPatientDue);
        BigDecimal collectedMonth = sum(invoices, paid.and(i -> !i.getPaidAt().isBefore(startOfMonth)), Invoice::getPatientDue);
        List<Invoice> unpaid = invoices.stream().filter(paid.negate()).toList();
        BigDecimal cnamReceivable = sum(invoices, i -> i.getCoverage() == CnamCoverage.PRIVATE_SECTOR
                && !i.getCreatedAt().isBefore(startOfMonth), Invoice::getCnamShare);
        return new BillingSummary(collectedToday, collectedMonth, unpaid.size(),
                sum(unpaid, i -> true, Invoice::getPatientDue), cnamReceivable, toInvoiceCount,
                properties.cnamRatePercent());
    }

    private InvoiceResponse toResponse(Invoice invoice) {
        return InvoiceResponse.from(invoice, verifier.url(invoice.getId()));
    }

    /** F-2026-000001 : numérotation continue par année (l'unicité est garantie par la base). */
    private String nextNumber() {
        String prefix = "F-" + Year.now(clock).getValue() + "-";
        return prefix + String.format("%06d", repository.countByNumberStartingWith(prefix) + 1);
    }

    private static CareAct suggestedAct(Doctor doctor) {
        return "Médecine générale".equals(doctor.getSpeciality().getName())
                ? CareAct.CONSULTATION : CareAct.SPECIALIST_CONSULTATION;
    }

    private static BigDecimal sum(List<Invoice> invoices, Predicate<Invoice> filter,
                                  Function<Invoice, BigDecimal> value) {
        return invoices.stream().filter(filter).map(value).reduce(BigDecimal.ZERO, BigDecimal::add)
                .setScale(3, RoundingMode.HALF_UP);
    }
}
