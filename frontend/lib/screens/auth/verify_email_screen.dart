import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_exception.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/ui_helpers.dart';

/// Saisie du code à 6 chiffres reçu par e-mail après l'inscription (ou à la connexion d'un compte
/// non vérifié). Compte actif → connecté directement ; sinon → en attente de validation admin.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key, required this.email});

  final String email;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  static const _resendDelay = 60;

  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  bool _loading = false;
  int _cooldown = _resendDelay; // un code vient d'être envoyé
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = _resendDelay);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final loggedIn = await context.read<AuthProvider>().verifyEmail(widget.email, _code.text);
      if (loggedIn || !mounted) return; // app.dart affiche l'espace de l'utilisateur
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Adresse e-mail vérifiée'),
          content: const Text('Votre compte sera actif après validation par un administrateur.'),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.displayMessage, isError: true);
      if (e.code == 'EMAIL_ALREADY_VERIFIED') Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    final sent = await runWithFeedback(
      context,
      () => context.read<AuthService>().resendVerification(widget.email),
      successMessage: 'Un nouveau code a été envoyé à ${widget.email}',
    );
    if (sent && mounted) _startCooldown();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Vérification de l\'e-mail')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.mark_email_read_outlined, size: 64, color: theme.colorScheme.primary),
                    const SizedBox(height: 16),
                    Text('Saisissez le code à 6 chiffres envoyé à',
                        textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
                    Text(widget.email,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Pensez à vérifier vos courriers indésirables (spam).',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 24),
                    CodeField(controller: _code, onSubmitted: _submit),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Vérifier'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _cooldown > 0 ? null : _resend,
                      child: Text(_cooldown > 0 ? 'Renvoyer le code (${_cooldown}s)' : 'Renvoyer le code'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Champ de saisie d'un code à 6 chiffres (partagé avec le mot de passe oublié).
class CodeField extends StatelessWidget {
  const CodeField({super.key, required this.controller, this.onSubmitted});

  final TextEditingController controller;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      autofillHints: const [AutofillHints.oneTimeCode],
      textAlign: TextAlign.center,
      maxLength: 6,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(letterSpacing: 8),
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: const InputDecoration(labelText: 'Code', counterText: '', prefixIcon: Icon(Icons.pin_outlined)),
      validator: (v) => (v == null || v.length != 6) ? 'Le code contient 6 chiffres' : null,
      onFieldSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
    );
  }
}
