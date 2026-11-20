import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/messaging_service.dart';
import 'ui_helpers.dart';

/// Lecteur d'un message vocal : l'audio n'est téléchargé qu'au premier appui sur lecture.
class VoiceMessagePlayer extends StatefulWidget {
  const VoiceMessagePlayer({super.key, required this.messageId, required this.durationMs, this.color});

  final int messageId;
  final int durationMs;
  final Color? color;

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  final AudioPlayer _player = AudioPlayer();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Source? _source;
  bool _loading = false;
  bool _playing = false;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _subscriptions
      ..add(_player.onPlayerStateChanged.listen((state) {
        if (mounted) setState(() => _playing = state == PlayerState.playing);
      }))
      ..add(_player.onPositionChanged.listen((p) {
        if (mounted) setState(() => _position = p);
      }))
      ..add(_player.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _position = Duration.zero);
      }));
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
      return;
    }
    if (_source == null) {
      setState(() => _loading = true);
      try {
        final audio = await context.read<MessagingService>().getAudio(widget.messageId);
        final mime = (audio.contentType ?? 'audio/webm').split(';').first;
        // Navigateur : URL "data:" (lecture native) ; téléphone : octets en mémoire
        _source = kIsWeb
            ? UrlSource('data:$mime;base64,${base64Encode(audio.bytes)}')
            : BytesSource(audio.bytes, mimeType: mime);
      } catch (e) {
        if (mounted) showSnack(context, errorMessage(e), isError: true);
        return;
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
    if (_position > Duration.zero) {
      await _player.resume();
    } else {
      await _player.play(_source!);
    }
  }

  static String _format(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    final total = Duration(milliseconds: widget.durationMs);
    final progress =
        total.inMilliseconds == 0 ? 0.0 : (_position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    return SizedBox(
      width: 220,
      child: Row(
        children: [
          IconButton(
            tooltip: _playing ? 'Pause' : 'Écouter',
            color: color,
            onPressed: _loading ? null : _toggle,
            icon: _loading
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: color))
                : Icon(_playing ? Icons.pause_circle_filled : Icons.play_circle_fill, size: 32),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(
                  value: progress,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.2),
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                ),
                const SizedBox(height: 4),
                Text(_format(_playing || _position > Duration.zero ? _position : total),
                    style: TextStyle(fontSize: 12, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
