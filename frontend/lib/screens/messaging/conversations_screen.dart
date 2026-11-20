import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/calls/call_service.dart';
import '../../core/utils/formatters.dart';
import '../../models/doctor.dart';
import '../../models/message.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../services/messaging_service.dart';
import '../../widgets/async_view.dart';
import '../../widgets/doctor_availability.dart';
import '../patient/assistant_screen.dart';
import 'chat_screen.dart';

/// Contacts de soin (médecins du patient, ou patients du médecin), avec ou sans message.
/// Une conversation n'existe qu'avec une relation de soin : un rendez-vous en attente, accepté ou terminé.
class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  Key _viewKey = UniqueKey();
  Timer? _refresh;
  StreamSubscription<DoctorStatus>? _statusSub;

  /// Médecin : son propre statut (renseigné par la pastille de disponibilité).
  Doctor? _me;

  @override
  void initState() {
    super.initState();
    _refresh = Timer.periodic(const Duration(seconds: 15), (_) => _reload());
    // Patient : badge « Absent » à jour dès qu'un médecin change de statut
    _statusSub = context.read<CallService>().doctorStatus.listen((_) => _reload());
  }

  @override
  void dispose() {
    _refresh?.cancel();
    _statusSub?.cancel();
    super.dispose();
  }

  void _reload() {
    if (mounted) setState(() => _viewKey = UniqueKey());
  }

  Future<void> _editAway() async {
    final me = _me;
    if (me == null) return;
    final updated = await showAwaySheet(context, me);
    if (updated != null && mounted) {
      setState(() {
        _me = updated;
        _chipKey = UniqueKey(); // la pastille recharge le nouveau statut
      });
    }
  }

  Key _chipKey = UniqueKey();

  @override
  Widget build(BuildContext context) {
    final role = context.read<AuthProvider>().user?.role;
    final contactsAreDoctors = role == UserRole.patient;
    final me = _me;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          // Médecin : se déclarer absent / disponible
          if (role == UserRole.doctor) DoctorAvailabilityChip(key: _chipKey, onChanged: (d) => setState(() => _me = d)),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          if (me != null && me.away)
            MaterialBanner(
              backgroundColor: Colors.orange.shade50,
              leading: const Icon(Icons.event_busy, color: Colors.deepOrange),
              content:
                  Text('Vous êtes indiqué absent${me.awayUntil == null ? '' : ' jusqu\'au ${Fmt.date(me.awayUntil)}'}. '
                      'Vos patients le voient et peuvent être pris en charge par l\'assistant santé.'),
              actions: [TextButton(onPressed: _editAway, child: const Text('Modifier'))],
            ),
          // Patient : réponse immédiate quand le médecin n'est pas disponible
          if (contactsAreDoctors)
            Card(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              color: Theme.of(context).colorScheme.primaryContainer,
              child: ListTile(
                leading: const Icon(Icons.smart_toy_outlined, size: 32),
                title: const Text('Assistant santé · 24 h/24', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Votre médecin n\'est pas disponible ? Posez votre question, '
                    'l\'assistant vous oriente et lui transmet si besoin.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AssistantScreen())),
              ),
            ),
          Expanded(child: _conversations(contactsAreDoctors)),
        ],
      ),
    );
  }

  Widget _conversations(bool contactsAreDoctors) {
    return AsyncView<List<Conversation>>(
      key: _viewKey,
      load: context.read<MessagingService>().getConversations,
      builder: (context, conversations, reload) => RefreshableList(
        onRefresh: reload,
        itemCount: conversations.length,
        empty: EmptyState(
          icon: Icons.forum_outlined,
          message: contactsAreDoctors
              ? 'Prenez rendez-vous avec un médecin pour pouvoir lui écrire ou l\'appeler.'
              : 'Vos patients apparaîtront ici dès leur première demande de rendez-vous.',
        ),
        itemBuilder: (context, i) {
          final c = conversations[i];
          final name = c.displayName(isDoctor: contactsAreDoctors);
          return _ConversationTile(
            conversation: c,
            name: name,
            onTap: () async {
              await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    ChatScreen(contactId: c.contactId, contactName: name, contactSubtitle: c.contactSubtitle),
              ));
              _reload();
            },
          );
        },
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation, required this.name, required this.onTap});

  final Conversation conversation;
  final String name;
  final VoidCallback onTap;

  static String _when(DateTime d) {
    final now = DateTime.now();
    if (DateUtils.isSameDay(d, now)) return Fmt.time(d);
    if (DateUtils.isSameDay(d, now.subtract(const Duration(days: 1)))) return 'Hier';
    return Fmt.date(d);
  }

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final scheme = Theme.of(context).colorScheme;
    final unread = c.unreadCount > 0;
    final subtitle = [if (c.contactSubtitle != null) c.contactSubtitle!, c.preview].join(' · ');
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          foregroundColor: scheme.onPrimaryContainer,
          child: Text(c.initials),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: unread ? FontWeight.bold : FontWeight.w500)),
            ),
            if (c.contactAway) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Absent', style: TextStyle(fontSize: 11, color: Colors.deepOrange.shade800)),
              ),
            ],
          ],
        ),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: unread ? scheme.onSurface : scheme.onSurfaceVariant,
            fontWeight: unread ? FontWeight.w600 : null,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (c.lastMessageAt != null) Text(_when(c.lastMessageAt!), style: Theme.of(context).textTheme.bodySmall),
            if (unread) ...[
              const SizedBox(height: 4),
              Badge(label: Text('${c.unreadCount}')),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bouton « Messages » de la barre du haut, avec le nombre de messages non lus.
class MessagesButton extends StatefulWidget {
  const MessagesButton({super.key});

  @override
  State<MessagesButton> createState() => _MessagesButtonState();
}

class _MessagesButtonState extends State<MessagesButton> {
  int _unread = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final count = await context.read<MessagingService>().getUnreadCount();
      if (mounted && count != _unread) setState(() => _unread = count);
    } catch (_) {
      // Badge non bloquant : nouvel essai au prochain cycle
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Messages',
      icon: Badge(
        isLabelVisible: _unread > 0,
        label: Text(_unread > 99 ? '99+' : '$_unread'),
        child: const Icon(Icons.forum_outlined),
      ),
      onPressed: () async {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConversationsScreen()));
        _refresh();
      },
    );
  }
}
