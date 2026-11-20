package com.healthcare.messaging;

import com.healthcare.messaging.dto.ConversationResponse;
import com.healthcare.messaging.dto.MessageResponse;
import com.healthcare.messaging.dto.SendMessageRequest;
import com.healthcare.messaging.dto.UnreadCountResponse;
import com.healthcare.security.SecurityUser;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * {@code contactId} = id du médecin pour un patient, id du patient pour un médecin
 * (l'autre participant est toujours déduit du token).
 */
@RestController
@RequestMapping("/api/messages")
@RequiredArgsConstructor
public class MessagingController {

    private final MessagingService messagingService;

    @GetMapping("/conversations")
    @PreAuthorize("hasAnyRole('PATIENT', 'DOCTOR')")
    public List<ConversationResponse> getConversations(@AuthenticationPrincipal SecurityUser me) {
        return messagingService.getConversations(me);
    }

    @GetMapping("/unread-count")
    @PreAuthorize("hasAnyRole('PATIENT', 'DOCTOR')")
    public UnreadCountResponse getUnreadCount(@AuthenticationPrincipal SecurityUser me) {
        return messagingService.getUnreadCount(me);
    }

    @GetMapping("/conversations/{contactId}")
    @PreAuthorize("hasAnyRole('PATIENT', 'DOCTOR')")
    public List<MessageResponse> getMessages(@PathVariable Long contactId,
                                             @RequestParam(required = false) Long beforeId,
                                             @RequestParam(required = false) Long afterId,
                                             @RequestParam(required = false) Integer size,
                                             @AuthenticationPrincipal SecurityUser me) {
        return messagingService.getMessages(me, contactId, beforeId, afterId, size);
    }

    @PostMapping("/conversations/{contactId}")
    @PreAuthorize("hasAnyRole('PATIENT', 'DOCTOR')")
    @ResponseStatus(HttpStatus.CREATED)
    public MessageResponse send(@PathVariable Long contactId,
                                @Valid @RequestBody SendMessageRequest request,
                                @AuthenticationPrincipal SecurityUser me) {
        return messagingService.send(me, contactId, request);
    }

    /** Message vocal : multipart (file = audio, durationMs = durée de l'enregistrement). */
    @PostMapping(path = "/conversations/{contactId}/voice", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasAnyRole('PATIENT', 'DOCTOR')")
    @ResponseStatus(HttpStatus.CREATED)
    public MessageResponse sendVoice(@PathVariable Long contactId,
                                     @RequestPart("file") MultipartFile file,
                                     @RequestParam int durationMs,
                                     @AuthenticationPrincipal SecurityUser me) {
        return messagingService.sendVoice(me, contactId, file, durationMs);
    }

    @GetMapping("/{messageId}/audio")
    @PreAuthorize("hasAnyRole('PATIENT', 'DOCTOR')")
    public ResponseEntity<byte[]> getAudio(@PathVariable Long messageId, @AuthenticationPrincipal SecurityUser me) {
        MessagingService.AudioContent audio = messagingService.getAudio(me, messageId);
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType(audio.contentType()))
                .cacheControl(CacheControl.noStore().cachePrivate())
                .header(HttpHeaders.CONTENT_DISPOSITION, "inline")
                .header("X-Content-Type-Options", "nosniff")
                .body(audio.data());
    }

    @PutMapping("/conversations/{contactId}/read")
    @PreAuthorize("hasAnyRole('PATIENT', 'DOCTOR')")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void markAsRead(@PathVariable Long contactId, @AuthenticationPrincipal SecurityUser me) {
        messagingService.markAsRead(me, contactId);
    }
}
