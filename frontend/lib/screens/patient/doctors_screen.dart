import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/doctor.dart';
import '../../models/speciality.dart';
import '../../services/doctor_service.dart';
import '../../widgets/async_view.dart';
import '../../widgets/doctor_card.dart';
import '../../widgets/ui_helpers.dart';
import 'doctor_details_screen.dart';

/// Recherche de médecins par nom et spécialité, avec pagination ("charger plus").
class DoctorsScreen extends StatefulWidget {
  const DoctorsScreen({super.key});

  @override
  State<DoctorsScreen> createState() => _DoctorsScreenState();
}

class _DoctorsScreenState extends State<DoctorsScreen> {
  final _query = TextEditingController();
  Timer? _debounce;

  List<Speciality> _specialities = [];
  int? _specialityId;

  final List<Doctor> _doctors = [];
  int _page = 0;
  bool _hasNext = false;
  bool _loading = false;
  bool _loadedOnce = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Après le premier rendu : _search appelle setState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSpecialities();
      _search(reset: true);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  Future<void> _loadSpecialities() async {
    try {
      final list = await context.read<DoctorService>().getSpecialities();
      if (mounted) setState(() => _specialities = list);
    } catch (_) {}
  }

  Future<void> _search({required bool reset}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _page = 0;
        _doctors.clear();
      }
    });
    try {
      final result = await context.read<DoctorService>().search(
            query: _query.text.trim(),
            specialityId: _specialityId,
            page: _page,
          );
      if (!mounted) return;
      setState(() {
        _doctors.addAll(result.content);
        _hasNext = result.hasNext;
        _page = result.page + 1;
      });
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadedOnce = true;
        });
      }
    }
  }

  void _onQueryChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(reset: true));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            controller: _query,
            onChanged: _onQueryChanged,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Rechercher un médecin',
            ),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _filterChip('Toutes', null),
              for (final s in _specialities) _filterChip(s.name, s.id),
            ],
          ),
        ),
        Expanded(child: _buildResults()),
      ],
    );
  }

  Widget _filterChip(String label, int? id) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ChoiceChip(
          label: Text(label),
          selected: _specialityId == id,
          onSelected: (_) {
            setState(() => _specialityId = id);
            _search(reset: true);
          },
        ),
      );

  Widget _buildResults() {
    if (_error != null && _doctors.isEmpty) {
      return ErrorState(message: _error!, onRetry: () => _search(reset: true));
    }
    if ((_loading || !_loadedOnce) && _doctors.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshableList(
      onRefresh: () => _search(reset: true),
      itemCount: _doctors.length + (_hasNext ? 1 : 0),
      empty: const EmptyState(icon: Icons.person_search, message: 'Aucun médecin trouvé'),
      itemBuilder: (context, i) {
        if (i == _doctors.length) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton(
              onPressed: _loading ? null : () => _search(reset: false),
              child: const Text('Charger plus'),
            ),
          );
        }
        final doctor = _doctors[i];
        return DoctorCard(
          doctor: doctor,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => DoctorDetailsScreen(doctorId: doctor.id)),
          ),
        );
      },
    );
  }
}
