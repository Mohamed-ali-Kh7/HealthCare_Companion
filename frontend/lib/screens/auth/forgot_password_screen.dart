import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../widgets/ui_helpers.dart';
import 'verify_email_screen.dart' show CodeField;

/// Mot de passe oublié : 1) e-mail → code envoyé ; 2) code + nouveau mot de passe.
/// Renvoie l'e-mail à l'écran de connexion une fois le mot de passe changé.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const _resendDelay = 60;

  final _emailForm = GlobalKey<FormState>();
  final _resetForm = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _codeSent = false;
  bool _loading = false;
  bool _obscure = true;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in [_email, _code, _password, _confirm]) {
      c.dispose();
    }
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

  Future<void> _sendCode() async {
    if (!_emailForm.currentState!.validate()) return;
    setState(() => _loading = true);
    final ok = await runWithFeedback(
      context,
      () => context.read<AuthService>().forgotPassword(_email.text.trim()),
      successMessage: 'Si un compte existe pour cette adresse, un code vient d\'y être envoyé.',
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (ok) _codeSent = true;
    });
    if (ok) _startCooldown();
  }

  Future<void> _reset() async {
    if (!_resetForm.currentState!.validate()) return;
    setState(() => _loading = true);
    final email = _email.text.trim();
    final ok = await runWithFeedback(
      context,
      () => context.read<AuthService>().resetPassword(email: email, code: _code.text, newPassword: _password.text),
      successMessage: 'Mot de passe modifié. Vous pouvez vous connecter.',
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) Navigator.pop(context, email);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Mot de passe oublié')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.lock_reset, size: 64, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Form(
                    key: _emailForm,
                    child: TextFormField(
                      controller: _email,
                      enabled: !_codeSent,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                      validator: Validators.email,
                      onFieldSubmitted: (_) => _sendCode(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!_codeSent) ...[
                    Text('Nous vous enverrons un code à 6 chiffres pour choisir un nouveau mot de passe.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loading ? null : _sendCode,
                      child: _loading ? _spinner() : const Text('Envoyer le code'),
                    ),
                  ] else
                    Form(
                      key: _resetForm,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Saisissez le code reçu par e-mail (pensez aux spams) et votre nouveau mot de passe.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                          const SizedBox(height: 16),
                          CodeField(controller: _code),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _password,
                            obscureText: _obscure,
                            autofillHints: const [AutofillHints.newPassword],
                            decoration: InputDecoration(
                              labelText: 'Nouveau mot de passe',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                tooltip: _obscure ? 'Afficher' : 'Masquer',
                                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: Validators.password,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _confirm,
                            obscureText: _obscure,
                            decoration: const InputDecoration(
                                labelText: 'Confirmer le mot de passe', prefixIcon: Icon(Icons.lock_outline)),
                            validator: (v) => v != _password.text ? 'Les mots de passe ne correspondent pas' : null,
                            onFieldSubmitted: (_) => _reset(),
                          ),
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: _loading ? null : _reset,
                            child: _loading ? _spinner() : const Text('Changer le mot de passe'),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _cooldown > 0 || _loading ? null : _sendCode,
                            child: Text(_cooldown > 0 ? 'Renvoyer le code (${_cooldown}s)' : 'Renvoyer le code'),
                          ),
                          TextButton(
                            onPressed: _loading ? null : () => setState(() => _codeSent = false),
                            child: const Text('Changer d\'adresse e-mail'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _spinner() =>
      const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2));
}
