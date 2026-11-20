import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

typedef VoiceRecording = ({Uint8List bytes, String contentType, int durationMs});

/// Enregistrement d'un message vocal : Opus/WebM dans le navigateur, AAC/M4A sur téléphone
/// (formats acceptés par le backend et lisibles des deux côtés).
class VoiceRecorder {
  final AudioRecorder _recorder = AudioRecorder();
  final Stopwatch _stopwatch = Stopwatch();
  String? _path;

  Duration get elapsed => _stopwatch.elapsed;

  /// Démarre l'enregistrement ; false si l'accès au micro est refusé.
  Future<bool> start() async {
    if (!await _recorder.hasPermission()) return false;
    if (kIsWeb) {
      _path = '';
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.opus), path: '');
    } else {
      final dir = await getTemporaryDirectory();
      _path = '${dir.path}/vocal_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000), path: _path!);
    }
    _stopwatch
      ..reset()
      ..start();
    return true;
  }

  /// Arrête et renvoie l'enregistrement (null s'il est vide ou illisible).
  Future<VoiceRecording?> stop() async {
    _stopwatch.stop();
    final result = await _recorder.stop();
    if (result == null) return null;
    final Uint8List bytes;
    if (kIsWeb) {
      // Le navigateur renvoie une URL "blob:" vers l'enregistrement
      bytes = (await http.get(Uri.parse(result))).bodyBytes;
    } else {
      final file = File(result);
      bytes = await file.readAsBytes();
      await file.delete().catchError((_) => file);
    }
    if (bytes.isEmpty) return null;
    return (
      bytes: bytes,
      contentType: kIsWeb ? 'audio/webm' : 'audio/mp4',
      durationMs: _stopwatch.elapsedMilliseconds,
    );
  }

  Future<void> cancel() async {
    _stopwatch.stop();
    await _recorder.cancel();
  }

  Future<void> dispose() => _recorder.dispose();
}
