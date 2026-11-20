package com.healthcare.billing;

import com.healthcare.billing.dto.BillingDtos.InvoiceResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.Locale;
import java.util.Optional;

import static org.springframework.web.util.HtmlUtils.htmlEscape;

/**
 * Page ouverte en scannant le QR code de la facture (CNAM, mutuelle, patient) : publique, protégée par le jeton
 * signé. Données réduites : initiale du nom du patient, pas de numéro CNAM complet.
 */
@RestController
@RequiredArgsConstructor
public class InvoiceVerificationController {

    private static final DateTimeFormatter DATE = DateTimeFormatter.ofPattern("d MMMM yyyy", Locale.FRENCH);

    private final BillingService service;

    @GetMapping(value = "/verify/invoice/{token}", produces = MediaType.TEXT_HTML_VALUE)
    public ResponseEntity<String> verify(@PathVariable String token) {
        Optional<InvoiceResponse> result = service.verifyPublic(token);
        return ResponseEntity.status(result.isPresent() ? HttpStatus.OK : HttpStatus.NOT_FOUND)
                .cacheControl(CacheControl.noStore())
                .header("X-Robots-Tag", "noindex, nofollow")
                .header("Referrer-Policy", "no-referrer")
                .contentType(new MediaType(MediaType.TEXT_HTML, StandardCharsets.UTF_8))
                .body(result.map(this::validPage).orElseGet(this::invalidPage));
    }

    private String validPage(InvoiceResponse i) {
        boolean paid = i.status() == InvoiceStatus.PAID;
        boolean transport = i.ambulanceRequestId() != null;
        String patient = e(i.patient().firstName()) + " " + e(initial(i.patient().lastName()));
        String paidLine = paid
                ? "Réglée le " + i.paidAt().atZone(ZoneId.systemDefault()).toLocalDate().format(DATE)
                + (i.paymentMethod() == PaymentMethod.CARD ? " (carte)" : " (espèces)")
                : "Non réglée";
        return page("Facture authentique", """
                <div class="badge ok">✓ Facture authentique</div>
                <p class=muted>Émise par HealthCare Companion · n° %s</p>
                <table>
                  <tr><td>%s</td><td><b>%s</b><br><span class=muted>%s</span></td></tr>
                  <tr><td>Patient</td><td><b>%s</b></td></tr>
                  <tr><td>%s</td><td><b>%s</b><br><span class=muted>%s</span></td></tr>
                  <tr><td>Montant</td><td><b>%s DT</b></td></tr>
                  <tr><td>CNAM</td><td>%s<br><span class=muted>Part CNAM : %s DT (%d %%)</span></td></tr>
                  <tr><td>Paiement</td><td><b class="%s">%s</b></td></tr>
                </table>
                <p class="muted small">Prise en charge CNAM simulée (projet académique). Comparez ces informations
                avec le document présenté : toute différence indique une facture modifiée.</p>
                """.formatted(e(i.number()), transport ? "Ambulance" : "Médecin", e(i.issuer().name()),
                e(i.issuer().subtitle()), patient, transport ? "Transport" : "Consultation", e(i.actLabel()),
                i.serviceDate().format(DATE),
                money(i.amount()), e(i.coverageLabel()), money(i.cnamShare()), i.cnamRatePercent(),
                paid ? "paid" : "unpaid", paidLine));
    }

    private String invalidPage() {
        return page("Facture non reconnue", """
                <div class="badge ko">✗ Facture non reconnue</div>
                <p>Ce QR code ne correspond à aucune facture émise par HealthCare Companion, ou le lien a été modifié.</p>
                """);
    }

    private static String page(String title, String body) {
        return """
                <!DOCTYPE html>
                <html lang="fr"><head><meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1">
                <meta name="robots" content="noindex">
                <title>%s</title>
                <style>
                  body{font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif;margin:0;background:#f4f7f6;color:#1d2b2a}
                  main{max-width:560px;margin:0 auto;padding:24px 18px}
                  header{color:#00796b;font-weight:700;font-size:15px;margin-bottom:16px}
                  .card{background:#fff;border-radius:14px;padding:20px;box-shadow:0 1px 4px rgba(0,0,0,.08)}
                  .badge{font-size:20px;font-weight:700;padding:14px;border-radius:10px;text-align:center}
                  .ok{background:#e3f4ec;color:#1b7a46}.ko{background:#fdeaea;color:#b3261e}
                  .paid{color:#1b7a46}.unpaid{color:#b3261e}
                  table{width:100%%;border-collapse:collapse;margin:12px 0}
                  td{padding:8px 0;border-bottom:1px solid #eee;vertical-align:top}
                  td:first-child{color:#667;width:110px}
                  .muted{color:#667}.small{font-size:13px;margin-top:16px}
                </style></head>
                <body><main><header>HealthCare Companion · Vérification de facture</header>
                <div class=card>%s</div></main></body></html>
                """.formatted(e(title), body);
    }

    private static String money(BigDecimal value) {
        return String.format(Locale.FRENCH, "%,.3f", value);
    }

    private static String initial(String lastName) {
        return lastName == null || lastName.isBlank() ? "" : lastName.substring(0, 1).toUpperCase(Locale.FRENCH) + ".";
    }

    private static String e(String value) {
        return value == null ? "" : htmlEscape(value);
    }
}
