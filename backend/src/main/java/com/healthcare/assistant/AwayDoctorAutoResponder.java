package com.healthcare.assistant;

import com.healthcare.messaging.PatientWroteToAwayDoctorEvent;
import com.healthcare.security.SecurityUser;
import com.healthcare.user.Role;
import jakarta.annotation.PreDestroy;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

/**
 * Quand un patient écrit à un médecin absent, l'assistant répond automatiquement dans la conversation,
 * 24 h/24. La réponse part quelques secondes après le dernier message : plusieurs messages envoyés à la suite
 * reçoivent une seule réponse. Traité hors de la requête du patient (l'IA peut prendre plusieurs secondes).
 */
@Slf4j
@Component
public class AwayDoctorAutoResponder {

    private final AssistantService assistantService;
    private final long delayMillis;
    private final Set<String> scheduled = ConcurrentHashMap.newKeySet();
    private final ScheduledExecutorService executor = Executors.newScheduledThreadPool(2, r -> {
        Thread t = new Thread(r, "assistant-auto-reply");
        t.setDaemon(true);
        return t;
    });

    public AwayDoctorAutoResponder(AssistantService assistantService,
                                   @Value("${app.assistant.auto-reply-delay-ms:3000}") long delayMillis) {
        this.assistantService = assistantService;
        this.delayMillis = delayMillis;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
    public void onPatientMessage(PatientWroteToAwayDoctorEvent event) {
        String key = event.patientUserId() + ":" + event.doctorId();
        if (!scheduled.add(key)) {
            return; // une réponse est déjà prévue : elle couvrira aussi ce message
        }
        executor.schedule(() -> {
            scheduled.remove(key);
            SecurityUser patient = new SecurityUser(event.patientUserId(), event.patientEmail(), "", Role.PATIENT, true);
            try {
                assistantService.autoReplyForAwayDoctor(patient, event.doctorId());
            } catch (Exception e) {
                log.warn("Réponse automatique impossible (patient user #{}, médecin #{})",
                        event.patientUserId(), event.doctorId(), e);
            }
        }, delayMillis, TimeUnit.MILLISECONDS);
    }

    @PreDestroy
    void shutdown() {
        executor.shutdownNow();
    }
}
