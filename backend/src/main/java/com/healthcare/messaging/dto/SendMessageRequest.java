package com.healthcare.messaging.dto;

import com.healthcare.messaging.Message;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record SendMessageRequest(
        @NotBlank @Size(max = Message.MAX_LENGTH) String content
) {
}
