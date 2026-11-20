import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../core/utils/launcher.dart';
import '../../core/utils/location_helper.dart';
import '../../models/assistant_message.dart';
import '../../services/ambulance_service.dart';
import '../../services/assistant_service.dart';
import '../../widgets/async_view.dart';
import '../../widgets/ui_helpers.dart';
import 'emergency_call_screen.dart';

/// Assistant santé 24 h/24 : répond quand le médecin n'est pas disponible, recueille les symptômes,
/// oriente, repère les urgences et transmet au médecin. Ne remplace pas une consultation.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  late final AssistantService _service = context.read<AssistantService>();
  late Future<void> _loading = _load();
  final List<AssistantMessage> _messages = [];
  bool _aiEnabled = true;
  bool _waiting = false;

  static const _suggestions = [
    'J\'ai de la fièvre depuis hier',
    'Puis-je prendre du paracétamol avec mon traitement ?',
    'Je voudrais renouveler mon ordonnance',
    'J\'ai mal à la tête depuis 3 jours',
  ];

  Future<void> _load() async {
    final results = await Future.wait([_service.history(), _service.isAiEnabled()]);
    _messages
      ..clear()
      ..addAll(results[0] as List<AssistantMessage>);
    _aiEnabled = results[1] as bool;
    _scrollToEnd();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _waiting) return;
    _input.clear();
    setState(() {
      _waiting = true;
      // Affiché tout de suite ; remplacé par l'historique serveur au prochain chargement
      _messages.add(AssistantMessage(id: -1, fromPatient: true, content: text, createdAt: DateTime.now()));
    });
    _scrollToEnd();
    try {
      final reply = await _service.ask(text);
      if (!mounted) return;
      setState(() => _messages.add(reply));
      _scrollToEnd();
      if (reply.urgent) _showEmergencySheet(reply.urgencyReason);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _waiting = false);
    }
  }

  void _showEmergencySheet(String? reason) {
    showModalBottomSheet<void>(
      context: context,
      isDismissible: true,
      builder: (sheet) => _EmergencySheet(reason: reason),
    );
  }

  Future<void> _newConversation() async {
    final ok = await confirm(context,
        title: 'Nouvelle conversation ?',
        message: 'L\'historique avec l\'assistant sera effacé. Les messages transmis à vos médecins sont conservés.',
        confirmLabel: 'Effacer');
    if (!ok || !mounted) return;
    final done = await runWithFeedback(context, _service.clear);
    if (done && mounted) setState(_messages.clear);
  }

  Future<void> _leaveMessage() async {
    final sent = await showModalBottomSheet<AssistantMessage>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _LeaveMessageSheet(service: _service),
    );
    if (sent != null && mounted) {
      setState(() => _messages.add(sent));
      _scrollToEnd();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.smart_toy_outlined),
          SizedBox(width: 8),
          Text('Assistant santé'),
        ]),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => v == 'doctor' ? _leaveMessage() : _newConversation(),
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: 'doctor',
                  child: ListTile(leading: Icon(Icons.forward_to_inbox), title: Text('Laisser un message au médecin'))),
              PopupMenuItem(
                  value: 'clear',
                  child: ListTile(leading: Icon(Icons.restart_alt), title: Text('Nouvelle conversation'))),
            ],
          ),
        ],
      ),
      body: FutureBuilder<void>(
        future: _loading,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorState(message: errorMessage(snapshot.error), onRetry: () => setState(() => _loading = _load()));
          }
          return Column(
            children: [
              _Disclaimer(aiEnabled: _aiEnabled),
              Expanded(
                child: ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  children: [
                    if (_messages.isEmpty) _Welcome(onSuggestion: _send, suggestions: _suggestions),
                    for (final m in _messages)
                      _Bubble(message: m, onEmergency: () => _showEmergencySheet(m.urgencyReason)),
                    if (_waiting) const _Typing(),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _input,
                          minLines: 1,
                          maxLines: 4,
                          maxLength: 2000,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: InputDecoration(
                            hintText: 'Décrivez vos symptômes ou posez votre question…',
                            counterText: '',
                            filled: true,
                            fillColor: theme.colorScheme.surfaceContainerHighest,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton.filled(
                        tooltip: 'Envoyer',
                        onPressed: _waiting ? null : _send,
                        icon: const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer({required this.aiEnabled});

  final bool aiEnabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.secondaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        '${aiEnabled ? 'Assistant disponible 24 h/24' : 'Mode simplifié (IA indisponible)'} · ne remplace pas votre médecin. '
        'Urgence : SAMU 190.',
        style: TextStyle(color: scheme.onSecondaryContainer, fontSize: 12.5),
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onSuggestion, required this.suggestions});

  final void Function(String) onSuggestion;
  final List<String> suggestions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(Icons.smart_toy_outlined, size: 56, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text('Bonjour, comment puis-je vous aider ?', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          const Text(
            'Je tiens compte de votre dossier (allergies, traitements, journal) et je peux transmettre '
            'votre demande à votre médecin.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [for (final s in suggestions) ActionChip(label: Text(s), onPressed: () => onSuggestion(s))],
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.onEmergency});

  final AssistantMessage message;
  final VoidCallback onEmergency;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final m = message;
    final mine = m.fromPatient;
    final bg = mine ? scheme.primary : (m.urgent ? Colors.red.shade50 : scheme.surfaceContainerHighest);
    final fg = mine ? scheme.onPrimary : (m.urgent ? Colors.red.shade900 : scheme.onSurface);

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.82),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          decoration: BoxDecoration(
            color: bg,
            border: m.urgent ? Border.all(color: Colors.red.shade300) : null,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(mine ? 16 : 4),
              bottomRight: Radius.circular(mine ? 4 : 16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (m.urgent)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 18),
                    const SizedBox(width: 4),
                    Text('Situation potentiellement urgente',
                        style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                  ]),
                ),
              SelectableText(m.content, style: TextStyle(color: fg, height: 1.35)),
              if (m.forwardedTo.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Chip(
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(Icons.forward_to_inbox, size: 16),
                    label: Text('Transmis à ${m.forwardedTo.join(', ')}'),
                  ),
                ),
              if (m.urgent)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
                    onPressed: onEmergency,
                    icon: const Icon(Icons.emergency),
                    label: const Text('Que faire maintenant'),
                  ),
                ),
              const SizedBox(height: 2),
              Text(
                '${Fmt.time(m.createdAt)}${!mine && !m.aiGenerated ? ' · réponse automatique simple' : ''}',
                style: TextStyle(color: fg.withValues(alpha: 0.6), fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Typing extends StatelessWidget {
  const _Typing();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 10),
          Text('L\'assistant consulte votre dossier…'),
        ]),
      ),
    );
  }
}

/// Situation urgente : appel au SAMU (écran d'appel) et alerte des médecins, en un geste.
class _EmergencySheet extends StatefulWidget {
  const _EmergencySheet({this.reason});

  final String? reason;

  @override
  State<_EmergencySheet> createState() => _EmergencySheetState();
}

class _EmergencySheetState extends State<_EmergencySheet> {
  bool _alerting = false;
  bool _alerted = false;

  Future<void> _alertDoctors() async {
    final service = context.read<AmbulanceService>();
    setState(() => _alerting = true);
    final position = await LocationHelper.current();
    if (!mounted) return;
    final ok = await runWithFeedback(
      context,
      () => service.sendEmergency(
        lat: position.isFallback ? null : position.lat,
        lng: position.isFallback ? null : position.lng,
        reason: 'Signalé par l\'assistant santé${widget.reason == null ? '' : ' : ${widget.reason}'}',
      ),
      successMessage: 'Vos médecins ont été alertés',
    );
    if (mounted) {
      setState(() {
        _alerting = false;
        _alerted = ok;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.emergency, color: Colors.red.shade700, size: 48),
            const SizedBox(height: 8),
            Text('Situation potentiellement urgente',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.red.shade800)),
            if (widget.reason != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(widget.reason!, textAlign: TextAlign.center),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style:
                  FilledButton.styleFrom(backgroundColor: Colors.red.shade700, minimumSize: const Size.fromHeight(54)),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(
                  fullscreenDialog: true,
                  builder: (_) => const EmergencyCallScreen(number: EmergencyNumbers.samu, label: 'SAMU'),
                ));
              },
              icon: const Icon(Icons.phone),
              label: const Text('Appeler le SAMU · 190', style: TextStyle(fontSize: 17)),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: _alerting || _alerted ? null : _alertDoctors,
              icon: _alerting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(_alerted ? Icons.check : Icons.emergency_share),
              label: Text(_alerted ? 'Médecins alertés' : 'Alerter mes médecins (avec ma position)'),
            ),
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Fermer')),
          ],
        ),
      ),
    );
  }
}

/// Le patient écrit lui-même à l'un de ses médecins (message transmis tel quel).
class _LeaveMessageSheet extends StatefulWidget {
  const _LeaveMessageSheet({required this.service});

  final AssistantService service;

  @override
  State<_LeaveMessageSheet> createState() => _LeaveMessageSheetState();
}

class _LeaveMessageSheetState extends State<_LeaveMessageSheet> {
  late final Future<List<AssistantDoctor>> _doctors = widget.service.doctors();
  final _text = TextEditingController();
  int? _doctorId;
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_doctorId == null || _text.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      final reply = await widget.service.leaveMessage(_doctorId!, _text.text.trim());
      if (mounted) Navigator.of(context).pop(reply);
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        showSnack(context, errorMessage(e), isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: FutureBuilder<List<AssistantDoctor>>(
        future: _doctors,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
          }
          final doctors = snapshot.data!;
          if (doctors.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Aucun médecin ne vous suit encore. Prenez rendez-vous depuis l\'onglet « Médecins ».'),
            );
          }
          _doctorId ??= doctors.first.id;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Laisser un message au médecin', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _doctorId,
                decoration: const InputDecoration(labelText: 'Médecin'),
                items: [
                  for (final d in doctors) DropdownMenuItem(value: d.id, child: Text('${d.name} · ${d.speciality}')),
                ],
                onChanged: (v) => setState(() => _doctorId = v),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _text,
                minLines: 3,
                maxLines: 6,
                maxLength: 1800,
                decoration: const InputDecoration(labelText: 'Votre message', alignLabelWithHint: true),
              ),
              FilledButton.icon(
                onPressed: _sending ? null : _submit,
                icon: const Icon(Icons.send),
                label: const Text('Envoyer au médecin'),
              ),
            ],
          );
        },
      ),
    );
  }
}
