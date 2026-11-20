package com.healthcare.auth.code;

/** Usage d'un code envoyé par e-mail : un code n'est valable que pour son usage. */
public enum CodePurpose {
    EMAIL_VERIFICATION,
    PASSWORD_RESET
}
