package com.healthcare.billing.dto;

import com.healthcare.billing.*;
import com.healthcare.doctor.Doctor;
import com.healthcare.patient.Patient;
import com.healthcare.transport.AmbulanceCompany;
import jakarta.validation.constraints.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;

public final class BillingDtos {

    private BillingDtos() {
    }

    /** Le médecin facture une consultation terminée. */
    public record CreateInvoiceRequest(
            Long appointmentId,
            Long ambulanceRequestId,
            @NotNull CareAct act,
            @NotNull @DecimalMin(value = "1.000", message = "Montant minimum : 1 DT")
            @DecimalMax(value = "2000.000", message = "Montant maximum : 2 000 DT")
            @Digits(integer = 4, fraction = 3) BigDecimal amount,
            @NotNull CnamCoverage coverage) {
    }

    /** Paiement par carte (simulé). Les données de carte ne sont pas enregistrées. */
    public record PayInvoiceRequest(
            @NotBlank @Size(max = 80) String holder,
            @NotBlank @Size(max = 25) String cardNumber,
            @NotBlank @Size(max = 5) String expiry,
            @NotBlank @Size(max = 4) String cvv) {
        @Override
        public String toString() {
            return "PayInvoiceRequest[card=****]";
        }
    }

    public record ActOption(CareAct code, String label, BigDecimal suggestedFee) {
    }

    public record PatientInfo(Long id, String firstName, String lastName, LocalDate dateOfBirth, String cnamNumber) {
        public static PatientInfo from(Patient p) {
            return new PatientInfo(p.getId(), p.getFirstName(), p.getLastName(), p.getDateOfBirth(), p.getCnamNumber());
        }
    }

    /** Émetteur de la facture : médecin (consultation) ou société d'ambulance conventionnée (transport). */
    public record Issuer(String kind, Long id, String name, String subtitle, String address, String phone) {
        public static Issuer from(Invoice i) {
            if (i.getCompany() != null) {
                AmbulanceCompany c = i.getCompany();
                return new Issuer("AMBULANCE_COMPANY", c.getId(), c.getName(),
                        "Ambulance conventionnée CNAM n° " + c.getConventionNumber(), c.getAddress(), c.getPhone());
            }
            Doctor d = i.getDoctor();
            return new Issuer("DOCTOR", d.getId(), "Dr " + d.getFirstName() + " " + d.getLastName(),
                    d.getSpeciality().getName(), d.getAddress(), d.getPhone());
        }
    }

    public record InvoiceResponse(
            Long id, String number, Instant issuedAt,
            CareAct act, String actLabel, BigDecimal amount,
            CnamCoverage coverage, String coverageLabel, String cnamNumber, int cnamRatePercent,
            BigDecimal cnamShare, BigDecimal patientDue,
            InvoiceStatus status, Instant paidAt, PaymentMethod paymentMethod, String paymentReference, String cardLast4,
            Long appointmentId, Long ambulanceRequestId, LocalDateTime serviceDate,
            PatientInfo patient, Issuer issuer,
            String verifyUrl) {

        public static InvoiceResponse from(Invoice i, String verifyUrl) {
            return new InvoiceResponse(i.getId(), i.getNumber(), i.getCreatedAt(),
                    i.getAct(), i.getAct().label(), i.getAmount(),
                    i.getCoverage(), i.getCoverage().label(), i.getCnamNumber(), i.getCnamRatePercent(),
                    i.getCnamShare(), i.getPatientDue(),
                    i.getStatus(), i.getPaidAt(), i.getPaymentMethod(), i.getPaymentReference(), i.getCardLast4(),
                    i.getAppointment() == null ? null : i.getAppointment().getId(),
                    i.getAmbulanceRequest() == null ? null : i.getAmbulanceRequest().getId(), i.getServiceDate(),
                    PatientInfo.from(i.getPatient()), Issuer.from(i),
                    verifyUrl);
        }
    }

    /**
     * Consultation terminée (médecin) ou transport terminé (société) pas encore facturé, avec l'acte et le tarif
     * proposés. Un seul des deux identifiants est renseigné.
     */
    public record ToInvoice(Long appointmentId, Long ambulanceRequestId, LocalDateTime serviceDate, String reason,
                            PatientInfo patient, CareAct suggestedAct, BigDecimal suggestedFee) {
    }

    /** Tableau de bord du médecin ou de la société (montants en dinars). */
    public record BillingSummary(BigDecimal collectedToday, BigDecimal collectedThisMonth,
                                long unpaidCount, BigDecimal unpaidAmount,
                                BigDecimal cnamReceivableThisMonth, long toInvoiceCount, int cnamRatePercent) {
    }
}
