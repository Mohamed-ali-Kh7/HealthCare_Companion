package com.healthcare.billing;

import com.healthcare.ambulance.AmbulanceRequest;
import com.healthcare.appointment.Appointment;
import com.healthcare.common.BaseEntity;
import com.healthcare.common.exception.BusinessRuleException;
import com.healthcare.doctor.Doctor;
import com.healthcare.patient.Patient;
import com.healthcare.transport.AmbulanceCompany;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.time.LocalDateTime;

/**
 * Facture d'une consultation terminée (émise par le médecin) ou d'un transport en ambulance conventionnée
 * (émise par la société). Une seule facture par consultation ou par transport. Montants en dinars, au millime près.
 * {@code patientDue} : ce que le patient paie à l'émetteur ; {@code cnamShare} : part de la CNAM (réglée à l'émetteur
 * en filière privée, remboursée au patient en système de remboursement).
 */
@Entity
@Table(name = "invoices", uniqueConstraints = {
        @UniqueConstraint(name = "uk_invoices_appointment", columnNames = "appointment_id"),
        @UniqueConstraint(name = "uk_invoices_ambulance_request", columnNames = "ambulance_request_id"),
        @UniqueConstraint(name = "uk_invoices_number", columnNames = "number")})
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Invoice extends BaseEntity {

    @Column(nullable = false, length = 20)
    private String number;

    /** Consultation facturée par un médecin (null pour un transport). */
    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "appointment_id")
    private Appointment appointment;

    /** Transport facturé par une société d'ambulance conventionnée (null pour une consultation). */
    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "ambulance_request_id")
    private AmbulanceRequest ambulanceRequest;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "patient_id", nullable = false)
    private Patient patient;

    /** Émetteur : le médecin (consultation) ou la société d'ambulance (transport). */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "doctor_id")
    private Doctor doctor;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "company_id")
    private AmbulanceCompany company;

    /** Date des soins : consultation ou transport. */
    @Column(name = "service_date", nullable = false)
    private LocalDateTime serviceDate;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    private CareAct act;

    @Column(nullable = false, precision = 10, scale = 3)
    private BigDecimal amount;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private CnamCoverage coverage;

    /** Numéro CNAM du patient au moment de la facture. */
    @Column(name = "cnam_number", length = 20)
    private String cnamNumber;

    @Column(name = "cnam_rate_percent", nullable = false)
    private int cnamRatePercent;

    @Column(name = "cnam_share", nullable = false, precision = 10, scale = 3)
    private BigDecimal cnamShare;

    @Column(name = "patient_due", nullable = false, precision = 10, scale = 3)
    private BigDecimal patientDue;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 10)
    private InvoiceStatus status = InvoiceStatus.UNPAID;

    @Column(name = "paid_at")
    private Instant paidAt;

    @Enumerated(EnumType.STRING)
    @Column(name = "payment_method", length = 10)
    private PaymentMethod paymentMethod;

    @Column(name = "payment_reference", length = 40)
    private String paymentReference;

    /** 4 derniers chiffres de la carte ; le numéro complet n'est jamais conservé. */
    @Column(name = "card_last4", length = 4)
    private String cardLast4;

    /** Consultation facturée par le médecin. */
    public Invoice(String number, Appointment appointment, CareAct act, BigDecimal amount, CnamCoverage coverage,
                   String cnamNumber, int cnamRatePercent) {
        this(number, appointment.getPatient(), act, amount, coverage, cnamNumber, cnamRatePercent);
        this.appointment = appointment;
        this.doctor = appointment.getDoctor();
        this.serviceDate = appointment.getAppointmentDate();
    }

    /** Transport facturé par la société d'ambulance conventionnée qui l'a réalisé. */
    public static Invoice forTransport(String number, AmbulanceRequest transport, CareAct act, BigDecimal amount,
                                       CnamCoverage coverage, String cnamNumber, int cnamRatePercent) {
        Invoice invoice = new Invoice(number, transport.getPatient(), act, amount, coverage, cnamNumber, cnamRatePercent);
        invoice.ambulanceRequest = transport;
        invoice.company = transport.getCompany();
        invoice.serviceDate = transport.getScheduledAt();
        return invoice;
    }

    private Invoice(String number, Patient patient, CareAct act, BigDecimal amount, CnamCoverage coverage,
                    String cnamNumber, int cnamRatePercent) {
        this.number = number;
        this.patient = patient;
        this.act = act;
        this.amount = amount.setScale(3, RoundingMode.HALF_UP);
        this.coverage = coverage;
        this.cnamNumber = cnamNumber;
        this.cnamRatePercent = coverage == CnamCoverage.NONE ? 0 : cnamRatePercent;
        this.cnamShare = this.amount.multiply(BigDecimal.valueOf(this.cnamRatePercent))
                .divide(BigDecimal.valueOf(100), 3, RoundingMode.HALF_UP);
        // Tiers payant : le patient ne règle que le ticket modérateur ; sinon il avance la totalité
        this.patientDue = coverage == CnamCoverage.PRIVATE_SECTOR ? this.amount.subtract(cnamShare) : this.amount;
    }

    public void markPaid(PaymentMethod method, String reference, String cardLast4, Instant when) {
        if (status == InvoiceStatus.PAID) {
            throw new BusinessRuleException("INVOICE_ALREADY_PAID", "Cette facture est déjà réglée");
        }
        this.status = InvoiceStatus.PAID;
        this.paymentMethod = method;
        this.paymentReference = reference;
        this.cardLast4 = cardLast4;
        this.paidAt = when;
    }
}
