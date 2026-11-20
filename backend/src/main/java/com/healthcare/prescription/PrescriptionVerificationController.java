package com.healthcare.prescription;

import com.healthcare.prescription.dto.PrescriptionResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

import java.time.format.DateTimeFormatter;
import java.util.Locale;
import java.util.Optional;

import static org.springframework.web.util.HtmlUtils.htmlEscape;

/**
 * Page ouverte en scannant le QR code de l'ordonnance PDF (pharmacien, patient) : publique, sans connexion.
 * Accès protégé par le jeton signé du lien. Données réduites : initiale du nom du patient seulement.
 */
@RestController
@RequiredArgsConstructor
public class PrescriptionVerificationController {

    private static final DateTimeFormatter DATE = DateTimeFormatter.ofPattern("d MMMM yyyy", Locale.FRENCH);

    private final PrescriptionService service;

    @GetMapping(value = "/verify/prescription/{token}", produces = MediaType.TEXT_HTML_VALUE)
    public ResponseEntity<String> verify(@PathVariable String token) {
        Optional<PrescriptionResponse> result = service.verifyPublic(token);
        return ResponseEntity.status(result.isPresent() ? HttpStatus.OK : HttpStatus.NOT_FOUND)
                .cacheControl(CacheControl.noStore())
                .header("X-Robots-Tag", "noindex, nofollow")
                .header("Referrer-Policy", "no-referrer")
                .contentType(new MediaType(MediaType.TEXT_HTML, java.nio.charset.StandardCharsets.UTF_8))
                .body(result.map(this::validPage).orElseGet(this::invalidPage));
    }

    private String validPage(PrescriptionResponse p) {
        StringBuilder items = new StringBuilder();
        int n = 1;
        for (PrescriptionResponse.Item i : p.items()) {
            items.append("<li><span class=num>").append(n++).append(".</span><div><b>")
                    .append(e(i.medicine().name())).append(' ').append(e(i.medicine().strength()))
                    .append("</b><br><span class=muted>").append(e(i.prescribedDosage())).append(" · ")
                    .append(i.timesPerDay()).append(" fois/jour · ").append(i.durationDays()).append(" jours")
                    .append("</span>");
            if (i.instructions() != null) {
                items.append("<br><i>").append(e(i.instructions())).append("</i>");
            }
            items.append("</div></li>");
        }
        String patient = e(p.patient().firstName()) + " " + e(initial(p.patient().lastName()));
        return page("Ordonnance authentique", """
                <div class="badge ok">✓ Ordonnance authentique</div>
                <p class=muted>Émise par HealthCare Companion · n° %d</p>
                <table>
                  <tr><td>Médecin</td><td><b>Dr %s %s</b><br><span class=muted>%s</span></td></tr>
                  <tr><td>Patient</td><td><b>%s</b></td></tr>
                  <tr><td>Date</td><td><b>%s</b></td></tr>
                </table>
                <h2>Médicaments prescrits</h2>
                <ol>%s</ol>
                <p class="muted small">Comparez ces informations avec le document présenté.
                Toute différence indique une ordonnance modifiée.</p>
                """.formatted(p.id(), e(p.doctor().firstName()), e(p.doctor().lastName()),
                e(p.doctor().specialityName()), patient, p.prescriptionDate().format(DATE), items));
    }

    private String invalidPage() {
        return page("Ordonnance non reconnue", """
                <div class="badge ko">✗ Ordonnance non reconnue</div>
                <p>Ce QR code ne correspond à aucune ordonnance émise par HealthCare Companion,
                ou le lien a été modifié.</p>
                <p class=muted>Ne délivrez pas de médicaments sur la base de ce document sans vérifier
                auprès du médecin prescripteur.</p>
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
                  table{width:100%%;border-collapse:collapse;margin:12px 0}
                  td{padding:8px 0;border-bottom:1px solid #eee;vertical-align:top}
                  td:first-child{color:#667;width:90px}
                  h2{font-size:16px;margin:18px 0 8px;color:#00796b}
                  ol{list-style:none;padding:0;margin:0}
                  li{display:flex;gap:10px;padding:8px 0;border-bottom:1px solid #f0f0f0}
                  .num{color:#00796b;font-weight:700}
                  .muted{color:#667}.small{font-size:13px;margin-top:16px}
                </style></head>
                <body><main><header>HealthCare Companion · Vérification d'ordonnance</header>
                <div class=card>%s</div></main></body></html>
                """.formatted(e(title), body);
    }

    private static String initial(String lastName) {
        return lastName == null || lastName.isBlank() ? "" : lastName.substring(0, 1).toUpperCase(Locale.FRENCH) + ".";
    }

    private static String e(String value) {
        return value == null ? "" : htmlEscape(value);
    }
}
