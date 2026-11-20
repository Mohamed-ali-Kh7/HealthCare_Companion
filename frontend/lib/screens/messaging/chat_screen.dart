import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/calls/call_service.dart';
import '../../core/media/voice_recorder.dart';
import '../../core/utils/formatters.dart';
import '../../models/message.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../services/assistant_service.dart';
import '../../services/doctor_service.dart';
import '../../services/messaging_service.dart';
import '../patient/assistant_screen.dart';
import '../../widgets/ui_helpers.dart';
import '../../widgets/voice_message_player.dart';

/// Conversation avec un contact de soin : texte, messages vocaux, appels audio et vidéo.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.contactId, required this.contactName, this.contactSubtitle});

  /// Id du médecin (côté patient) ou du patient (côté médecin).
  final int contactId;
  final String contactName;
  final String? contactSubtitle;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  /// Rafraîchissement : nouveaux messages, accusés de lecture, durée des appels.
  static const _pollInterval = Duration(seconds: 4);
  static const _pageSize = 50;
  static const _maxVoice = Duration(minutes: 5);

  final _text = TextEditingController();
  final _scroll = ScrollController();
  final _recorder = VoiceRecorder();

  List<ChatMessage> _messages = [];
  bool _loading = true;
  Object? _error;
  bool _hasOlder = true;
  bool _loadingOlder = false;
  bool _sending = false;
  bool _recording = false;
  Timer? _poll;
  Timer? _recordTicker;

  MessagingService get _service => context.read<MessagingService>();

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
    _scroll.addListener(_onScroll);
    _loadLatest(initial: true);
    _poll = Timer.periodic(_pollInterval, (_) => _loadLatest());
    _watchDoctorStatus();
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _poll?.cancel();
    _recordTicker?.cancel();
    _recorder.dispose();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- Chargement

  /// Dernière page : fusionnée avec l'historique déjà chargé (les messages récents sont remplacés).
  Future<void> _loadLatest({bool initial = false}) async {
    try {
      final page = await _service.getMessages(widget.contactId);
      if (!mounted) return;
      final atBottom = initial || _isNearBottom();
      final hadUnread = page.any((m) => !m.mine && m.readAt == null);
      setState(() {
        if (page.isEmpty) {
          _messages = [];
        } else {
          final oldest = page.first.id;
          _messages = [..._messages.where((m) => m.id < oldest), ...page];
        }
        if (initial) _hasOlder = page.length >= _pageSize;
        _loading = false;
        _error = null;
      });
      if (atBottom) _scrollToBottom();
      if (hadUnread) _service.markAsRead(widget.contactId).catchError((_) {});
    } catch (e) {
      if (mounted && initial) {
        setState(() {
          _loading = false;
          _error = e;
        });
      }
    }
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder || !_hasOlder || _messages.isEmpty) return;
    setState(() => _loadingOlder = true);
    try {
      final older = await _service.getMessages(widget.contactId, beforeId: _messages.first.id);
      if (!mounted) return;
      final previousExtent = _scroll.position.maxScrollExtent;
      setState(() {
        _messages = [...older, ..._messages];
        _hasOlder = older.length >= _pageSize;
      });
      // Garde le message affiché à la même place à l'écran
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.offset + _scroll.position.maxScrollExtent - previousExtent);
        }
      });
    } catch (_) {
      // Nouvelle tentative au prochain défilement
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  void _onScroll() {
    if (_scroll.hasClients && _scroll.position.pixels < 80) _loadOlder();
  }

  bool _isNearBottom() => !_scroll.hasClients || _scroll.position.maxScrollExtent - _scroll.position.pixels < 120;

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  void _append(ChatMessage message) {
    setState(() {
      if (!_messages.any((m) => m.id == message.id)) _messages = [..._messages, message];
    });
    _scrollToBottom();
  }

  // ---------------------------------------------------------------- Envoi

  Future<void> _sendText() async {
    final content = _text.text.trim();
    if (content.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final sent = await _service.sendText(widget.contactId, content);
      _text.clear();
      _append(sent);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _startRecording() async {
    final ok = await _recorder.start().catchError((_) => false);
    if (!mounted) return;
    if (!ok) {
      showSnack(context, 'Accès au micro refusé : autorisez-le pour envoyer un message vocal', isError: true);
      return;
    }
    setState(() => _recording = true);
    _recordTicker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      if (_recorder.elapsed >= _maxVoice) {
        _stopRecording(send: true);
      } else {
        setState(() {});
      }
    });
  }

  Future<void> _stopRecording({required bool send}) async {
    _recordTicker?.cancel();
    if (!_recording) return;
    setState(() => _recording = false);
    if (!send) {
      await _recorder.cancel();
      return;
    }
    final recording = await _recorder.stop();
    if (recording == null || recording.durationMs < 500) {
      if (mounted) showSnack(context, 'Message vocal trop court');
      return;
    }
    setState(() => _sending = true);
    try {
      final sent = await _service.sendVoice(widget.contactId,
          bytes: recording.bytes, contentType: recording.contentType, durationMs: recording.durationMs);
      _append(sent);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _call({required bool video}) {
    context.read<CallService>().startCall(
          contactId: widget.contactId,
          name: widget.contactName,
          subtitle: widget.contactSubtitle,
          video: video,
        );
  }

  // ---------------------------------------------------------------- Interface

  @override
  Widget build(BuildContext context) {
    final busy = context.watch<CallService>().isBusy;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.contactName, overflow: TextOverflow.ellipsis),
            if (widget.contactSubtitle != null)
              Text(widget.contactSubtitle!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Appel audio',
            icon: const Icon(Icons.call),
            onPressed: busy ? null : () => _call(video: false),
          ),
          IconButton(
            tooltip: 'Appel vidéo',
            icon: const Icon(Icons.videocam),
            onPressed: busy ? null : () => _call(video: true),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_doctorAway != null) _awayBanner(_doctorAway!),
          Expanded(child: _buildMessages()),
          _buildComposer(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- Médecin absent (côté patient)

  /// Statut du médecin quand le patient consulte la conversation ; null = disponible (ou côté médecin).
  ({String? message, DateTime? until})? _doctorAway;
  StreamSubscription<DoctorStatus>? _statusSub;
  bool _transferring = false;

  void _watchDoctorStatus() {
    if (context.read<AuthProvider>().user?.role != UserRole.patient) return;
    context.read<DoctorService>().getById(widget.contactId).then((d) {
      if (mounted) setState(() => _doctorAway = d.away ? (message: d.awayMessage, until: d.awayUntil) : null);
    }).catchError((_) {});
    _statusSub = context.read<CallService>().doctorStatus.listen((s) {
      if (!mounted || s.doctorId != widget.contactId) return;
      setState(() => _doctorAway = s.away ? (message: s.message, until: s.until) : null);
    });
  }

  /// L'assistant reprend les derniers messages restés sans réponse et répond au patient.
  Future<void> _transferToAssistant() async {
    setState(() => _transferring = true);
    try {
      await context.read<AssistantService>().handoff(widget.contactId);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AssistantScreen()));
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _transferring = false);
    }
  }

  Widget _awayBanner(({String? message, DateTime? until}) away) {
    return Material(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.event_busy, color: Colors.deepOrange),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${widget.contactName} est absent${away.until == null ? '' : ' jusqu\'au ${Fmt.date(away.until)}'}.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (away.message != null)
              Padding(
                padding: const EdgeInsets.only(left: 34, top: 2),
                child: Text('« ${away.message} »', style: const TextStyle(fontStyle: FontStyle.italic)),
              ),
            const Padding(
              padding: EdgeInsets.only(left: 34, top: 2),
              child: Text('Vos messages seront lus à son retour. En attendant, l\'assistant santé 🤖 vous répond '
                  'automatiquement ici. Pour continuer la discussion avec lui :'),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _transferring ? null : _transferToAssistant,
                icon: _transferring
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.smart_toy_outlined),
                label: Text(_transferring ? 'Transfert en cours…' : 'Transférer à l\'assistant'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessages() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(errorMessage(_error), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                setState(() => _loading = true);
                _loadLatest(initial: true);
              },
              child: const Text('Réessayer'),
            ),
          ]),
        ),
      );
    }
    if (_messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Aucun message pour le moment.\nÉcrivez, envoyez un vocal ou lancez un appel.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _messages.length + (_loadingOlder ? 1 : 0),
      itemBuilder: (context, index) {
        if (_loadingOlder) {
          if (index == 0) {
            return const Padding(
              padding: EdgeInsets.all(8),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            );
          }
          index--;
        }
        final m = _messages[index];
        final previous = index > 0 ? _messages[index - 1] : null;
        final newDay = previous == null || !DateUtils.isSameDay(previous.sentAt, m.sentAt);
        return Column(
          children: [
            if (newDay) _DaySeparator(date: m.sentAt),
            m.type == MessageType.call ? _CallEntry(message: m) : _Bubble(message: m),
          ],
        );
      },
    );
  }

  Widget _buildComposer() {
    final scheme = Theme.of(context).colorScheme;
    if (_recording) {
      final e = _recorder.elapsed;
      return SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          color: scheme.surfaceContainerLow,
          child: Row(
            children: [
              IconButton(
                tooltip: 'Annuler',
                icon: Icon(Icons.delete_outline, color: scheme.error),
                onPressed: () => _stopRecording(send: false),
              ),
              Icon(Icons.fiber_manual_record, color: scheme.error, size: 14),
              const SizedBox(width: 8),
              Text('Enregistrement… ${e.inMinutes}:${(e.inSeconds % 60).toString().padLeft(2, '0')}'),
              const Spacer(),
              IconButton.filled(
                tooltip: 'Envoyer le vocal',
                icon: const Icon(Icons.send),
                onPressed: () => _stopRecording(send: true),
              ),
            ],
          ),
        ),
      );
    }

    final hasText = _text.text.trim().isNotEmpty;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        color: scheme.surfaceContainerLow,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _text,
                minLines: 1,
                maxLines: 5,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'Votre message', counterText: '', isDense: true),
                onSubmitted: (_) => _sendText(),
              ),
            ),
            const SizedBox(width: 6),
            if (_sending)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (hasText)
              IconButton.filled(tooltip: 'Envoyer', icon: const Icon(Icons.send), onPressed: _sendText)
            else
              IconButton.filledTonal(
                tooltip: 'Message vocal',
                icon: const Icon(Icons.mic),
                onPressed: _startRecording,
              ),
          ],
        ),
      ),
    );
  }
}

class _DaySeparator extends StatelessWidget {
  const _DaySeparator({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final label = DateUtils.isSameDay(date, now)
        ? "Aujourd'hui"
        : DateUtils.isSameDay(date, now.subtract(const Duration(days: 1)))
            ? 'Hier'
            : Fmt.dateLong(date);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mine = message.mine;
    final assistant = message.type == MessageType.assistant;
    final background = mine
        ? scheme.primary
        : assistant
            ? scheme.tertiaryContainer
            : scheme.surfaceContainerHigh;
    final foreground = mine
        ? scheme.onPrimary
        : assistant
            ? scheme.onTertiaryContainer
            : scheme.onSurface;
    final meta = TextStyle(fontSize: 11, color: foreground.withValues(alpha: 0.75));

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (assistant)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('🤖 Assistant santé · réponse automatique',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: foreground)),
                ),
              ),
            if (message.type == MessageType.voice)
              VoiceMessagePlayer(
                messageId: message.id,
                durationMs: message.audioDurationMs ?? 0,
                color: foreground,
              )
            else
              SelectableText(message.content ?? '', style: TextStyle(color: foreground)),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(Fmt.time(message.sentAt), style: meta),
                if (mine) ...[
                  const SizedBox(width: 4),
                  Icon(message.readAt != null ? Icons.done_all : Icons.done,
                      size: 14,
                      color: foreground.withValues(alpha: 0.75),
                      semanticLabel: message.readAt != null ? 'Lu' : 'Envoyé'),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Trace d'un appel dans la conversation.
class _CallEntry extends StatelessWidget {
  const _CallEntry({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final video = message.callVideo ?? false;
    final seconds = message.callDurationSeconds;
    final missed = seconds == null;
    final kind = video ? 'Appel vidéo' : 'Appel audio';
    final String label;
    if (missed) {
      label = message.mine ? '$kind sans réponse' : '$kind manqué';
    } else {
      final duration = seconds >= 60 ? '${seconds ~/ 60} min ${seconds % 60} s' : '$seconds s';
      label = '$kind · $duration';
    }
    final color = missed && !message.mine ? scheme.error : scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                missed ? Icons.phone_missed : (video ? Icons.videocam : Icons.call),
                size: 16,
                color: color,
              ),
              const SizedBox(width: 6),
              Text('$label · ${Fmt.time(message.sentAt)}', style: TextStyle(fontSize: 12, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
