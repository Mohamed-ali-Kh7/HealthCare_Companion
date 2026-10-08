package com.healthcare.user;

import com.healthcare.common.dto.PageResponse;
import com.healthcare.security.SecurityUser;
import com.healthcare.user.dto.ChangePasswordRequest;
import com.healthcare.user.dto.UpdateUserStatusRequest;
import com.healthcare.user.dto.UserResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/users")
@RequiredArgsConstructor
public class UserController {

    private final UserService userService;

    @GetMapping
    @PreAuthorize("hasRole('ADMIN')")
    public PageResponse<UserResponse> search(@RequestParam(required = false) String q,
                                             @RequestParam(required = false) Role role,
                                             @RequestParam(required = false) Boolean enabled,
                                             @PageableDefault(size = 20, sort = "createdAt",
                                                     direction = Sort.Direction.DESC) Pageable pageable) {
        return userService.search(q, role, enabled, pageable);
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public UserResponse getById(@PathVariable Long id) {
        return userService.getById(id);
    }

    /**
     * Remplace le DELETE prévu dans le README : on désactive au lieu de supprimer,
     * pour préserver l'historique médical (rendez-vous, ordonnances).
     */
    @PatchMapping("/{id}/status")
    @PreAuthorize("hasRole('ADMIN')")
    public UserResponse updateStatus(@PathVariable Long id,
                                     @Valid @RequestBody UpdateUserStatusRequest request,
                                     @AuthenticationPrincipal SecurityUser me) {
        return userService.setEnabled(id, request.enabled(), me.id());
    }

    @PutMapping("/me/password")
    public ResponseEntity<Void> changePassword(@Valid @RequestBody ChangePasswordRequest request,
                                               @AuthenticationPrincipal SecurityUser me) {
        userService.changePassword(me.id(), request.currentPassword(), request.newPassword());
        return ResponseEntity.noContent().build();
    }
}
