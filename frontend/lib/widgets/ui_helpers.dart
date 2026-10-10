import 'package:flutter/material.dart';

import '../core/network/api_exception.dart';

/// Message lisible pour n'importe quelle erreur (API ou inattendue).
String errorMessage(Object? error) {
  if (error is ApiException) return error.displayMessage;
  return 'Une erreur inattendue est survenue.';
}

void showSnack(BuildContext context, String message, {bool isError = false}) {
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? scheme.error : null,
      behavior: SnackBarBehavior.floating,
    ));
}

/// Exécute une action réseau avec retour visuel (succès / erreur).
Future<bool> runWithFeedback(
  BuildContext context,
  Future<void> Function() action, {
  String? successMessage,
}) async {
  try {
    await action();
    if (context.mounted && successMessage != null) showSnack(context, successMessage);
    return true;
  } catch (e) {
    if (context.mounted) showSnack(context, errorMessage(e), isError: true);
    return false;
  }
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmer',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  minimumSize: const Size(0, 40))
              : FilledButton.styleFrom(minimumSize: const Size(0, 40)),
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Petite boîte de saisie de texte (motif de refus, note...).
Future<String?> promptText(
  BuildContext context, {
  required String title,
  String hint = '',
  String confirmLabel = 'Valider',
}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        maxLength: 500,
        maxLines: 3,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}

/// Validateurs de formulaires réutilisables.
class Validators {
  Validators._();

  static String? required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Champ obligatoire' : null;

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Champ obligatoire';
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim()) ? null : 'Email invalide';
  }

  /// Même politique que le backend (PasswordPolicy).
  static String? password(String? v) {
    if (v == null || v.length < 8 || v.length > 72) return '8 à 72 caractères';
    if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) {
      return 'Au moins une lettre et un chiffre';
    }
    return null;
  }

  static String? phone(String? v) {
    if (v == null || v.isEmpty) return null;
    return RegExp(r'^[+0-9 ]*$').hasMatch(v) ? null : 'Numéro invalide';
  }
}
