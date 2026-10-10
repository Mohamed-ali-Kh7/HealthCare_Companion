import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../services/admin_service.dart';
import '../../widgets/async_view.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/ui_helpers.dart';

/// Gestion des comptes : validation des médecins / pharmaciens, activation / désactivation.
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

/// Filtre : null = tous ; sinon (rôle, actif).
typedef _Filter = ({String label, UserRole? role, bool? enabled});

class _UsersScreenState extends State<UsersScreen> {
  static const List<_Filter> _filters = [
    (label: 'À valider / inactifs', role: null, enabled: false),
    (label: 'Tous', role: null, enabled: null),
    (label: 'Patients', role: UserRole.patient, enabled: null),
    (label: 'Médecins', role: UserRole.doctor, enabled: null),
    (label: 'Pharmaciens', role: UserRole.pharmacist, enabled: null),
    (label: 'Admins', role: UserRole.admin, enabled: null),
  ];

  _Filter _filter = _filters.first;
  final _query = TextEditingController();
  Timer? _debounce;

  final List<User> _users = [];
  int _page = 0;
  bool _hasNext = false;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  Future<void> _load({required bool reset}) async {
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _page = 0;
        _users.clear();
      }
    });
    try {
      final result = await context.read<AdminService>().searchUsers(
            query: _query.text.trim(),
            role: _filter.role,
            enabled: _filter.enabled,
            page: _page,
          );
      if (!mounted) return;
      setState(() {
        _users.addAll(result.content);
        _hasNext = result.hasNext;
        _page = result.page + 1;
      });
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(User user, bool enabled) async {
    if (!enabled) {
      final ok = await confirm(context,
          title: 'Désactiver ce compte ?',
          message: '${user.email} ne pourra plus se connecter. L\'historique médical est conservé.',
          confirmLabel: 'Désactiver',
          destructive: true);
      if (!ok || !mounted) return;
    }
    User? updated;
    final done = await runWithFeedback(
      context,
      () async => updated = await context.read<AdminService>().setUserEnabled(user.id, enabled),
      successMessage: enabled ? 'Compte activé' : 'Compte désactivé',
    );
    if (done && updated != null && mounted) {
      setState(() {
        final i = _users.indexWhere((u) => u.id == user.id);
        if (i >= 0) _users[i] = updated!;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = context.watch<AuthProvider>().user?.id;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            controller: _query,
            onChanged: (_) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 400), () => _load(reset: true));
            },
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Rechercher par email'),
          ),
        ),
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            children: [
              for (final f in _filters)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(f.label),
                    selected: _filter == f,
                    onSelected: (_) {
                      setState(() => _filter = f);
                      _load(reset: true);
                    },
                  ),
                ),
            ],
          ),
        ),
        if (_loading && _users.isEmpty) const LinearProgressIndicator(),
        Expanded(
          child: _error != null && _users.isEmpty
              ? ErrorState(message: _error!, onRetry: () => _load(reset: true))
              : RefreshableList(
                  onRefresh: () => _load(reset: true),
                  itemCount: _users.length + (_hasNext ? 1 : 0),
                  empty: _loading
                      ? const SizedBox.shrink()
                      : const EmptyState(icon: Icons.person_off_outlined, message: 'Aucun compte'),
                  itemBuilder: (context, i) {
                    if (i == _users.length) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: OutlinedButton(
                          onPressed: _loading ? null : () => _load(reset: false),
                          child: const Text('Charger plus'),
                        ),
                      );
                    }
                    final u = _users[i];
                    return Card(
                      child: ListTile(
                        title: Text(u.email),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              StatusChip(label: u.role.label, color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 8),
                              if (u.createdAt != null) Text('Inscrit le ${Fmt.date(u.createdAt)}'),
                            ],
                          ),
                        ),
                        trailing: Switch(
                          value: u.enabled,
                          onChanged: u.id == myId ? null : (v) => _toggle(u, v),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
