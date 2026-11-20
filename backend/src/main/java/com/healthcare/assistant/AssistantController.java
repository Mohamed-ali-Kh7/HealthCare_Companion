package com.healthcare.assistant;

import com.healthcare.assistant.dto.AssistantDtos.*;
import com.healthcare.security.SecurityUser;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/assistant")
@PreAuthorize("hasRole('PATIENT')")
@RequiredArgsConstructor
public class AssistantController {

    private final AssistantService service;

    @GetMapping("/status")
    public StatusResponse status() {
        return service.status();
    }

    @GetMapping("/messages")
    public List<MessageResponse> history(@AuthenticationPrincipal SecurityUser me) {
        return service.history(me.id());
    }

    /** Envoie un message et renvoie la réponse de l'assistant (quelques secondes avec l'IA). */
    @PostMapping("/messages")
    public MessageResponse ask(@AuthenticationPrincipal SecurityUser me, @Valid @RequestBody AskRequest request) {
        return service.ask(me, request.message());
    }

    @DeleteMapping("/messages")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void clear(@AuthenticationPrincipal SecurityUser me) {
        service.clear(me.id());
    }

    @GetMapping("/doctors")
    public List<DoctorOption> doctors(@AuthenticationPrincipal SecurityUser me) {
        return service.myDoctors(me);
    }

    /** « Transférer à l'assistant » depuis la conversation avec un médecin indisponible. */
    @PostMapping("/handoff")
    public MessageResponse handoff(@AuthenticationPrincipal SecurityUser me, @Valid @RequestBody HandoffRequest request) {
        return service.handoff(me, request.doctorId());
    }

    @PostMapping("/doctor-message")
    public MessageResponse leaveMessage(@AuthenticationPrincipal SecurityUser me,
                                        @Valid @RequestBody DoctorMessageRequest request) {
        return service.leaveMessageForDoctor(me, request.doctorId(), request.message());
    }
}
