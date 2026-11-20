package com.healthcare.auth.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/** Renvoi du code de vérification / mot de passe oublié. */
public record EmailRequest(@NotBlank @Email @Size(max = 150) String email) {
}
