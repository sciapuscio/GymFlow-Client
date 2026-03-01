import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../../core/constants.dart';
import '../../../features/auth/auth_provider.dart';
import '../models/rm_models.dart';
import 'rm_history_screen.dart';

class RmCalculatorScreen extends StatefulWidget {
  final int? sessionId;
  const RmCalculatorScreen({super.key, this.sessionId});

  @override
  State<RmCalculatorScreen> createState() => _RmCalculatorScreenState();
}

class _RmCalculatorScreenState extends State<RmCalculatorScreen> {
  List<RmEntry> _entries = [];
  String _sessionName = '';
  bool _loading = true;
  bool _saving = false;
  String? _error;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _fetchSession();
  }

  Future<String?> _getToken() async {
    final auth = context.read<AuthProvider>();
    return auth.token;
  }

  Future<void> _fetchSession() async {
    if (widget.sessionId == null) {
      // Manual mode — start with one blank free-form entry
      setState(() {
        _loading = false;
        _sessionName = 'Entrada manual';
        _entries = [
          RmEntry(
            exercise: const RmExercise(
                name: '', reps: 5, blockName: 'Manual', blockType: 'manual'),
            reps: 5,
          ),
        ];
      });
      return;
    }
    final token = await _getToken();
    if (token == null) { setState(() { _loading = false; _error = 'Sin sesión.'; }); return; }
    try {
      final uri = Uri.parse('${AppConstants.rmCalculatorUrl}?session_id=${widget.sessionId}');
      final r = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
      final body = json.decode(r.body) as Map<String, dynamic>;
      if (r.statusCode != 200) {
        setState(() { _loading = false; _error = body['error'] ?? 'Error'; });
        return;
      }
      final exList = (body['exercises'] as List? ?? [])
          .map((e) => RmExercise.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _loading = false;
        _sessionName = body['session_name'] as String? ?? '';
        _entries = exList.map((ex) => RmEntry(exercise: ex, reps: ex.reps)).toList();
      });
    } catch (e) {
      setState(() { _loading = false; _error = 'Error de red: $e'; });
    }
  }

  Future<void> _save() async {
    final validEntries = _entries.where((e) => e.weightKg > 0 && e.reps > 0 && e.reps < 37).toList();
    if (validEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresá al menos un peso para guardar.')),
      );
      return;
    }
    setState(() => _saving = true);
    final token = await _getToken();
    try {
      final r = await http.post(
        Uri.parse(AppConstants.rmCalculatorUrl),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: json.encode({
          'session_id': widget.sessionId,
          'entries': validEntries.map((e) => e.toJson()).toList(),
        }),
      );
      if (r.statusCode == 201) {
        setState(() { _saving = false; _saved = true; });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${validEntries.length} ejercicio${validEntries.length > 1 ? 's' : ''} guardado${validEntries.length > 1 ? 's' : ''}'),
              backgroundColor: const Color(0xFF00F5D4),
            ),
          );
        }
      } else {
        final err = json.decode(r.body)['error'] ?? 'Error al guardar';
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
        setState(() => _saving = false);
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080810),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14141E),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Calculadora RM', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            if (_sessionName.isNotEmpty)
              Text(_sessionName, style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded, color: Color(0xFF00F5D4)),
            tooltip: 'Mi historial',
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => const RmHistoryScreen(),
            )),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00F5D4)))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Color(0xFFEF4444))))
              : _entries.isEmpty
                  ? const Center(child: Text('No hay ejercicios con reps en esta sesión.',
                      style: TextStyle(color: Color(0xFF888888))))
                  : Column(
                      children: [
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _entries.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (_, i) => _ExerciseCard(
                              entry: _entries[i],
                              onChanged: () => setState(() {}),
                            ),
                          ),
                        ),
                        _SaveButton(saving: _saving, saved: _saved, onPressed: _save),
                      ],
                    ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
class _ExerciseCard extends StatefulWidget {
  final RmEntry entry;
  final VoidCallback onChanged;
  const _ExerciseCard({required this.entry, required this.onChanged});

  @override
  State<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<_ExerciseCard> {
  late final TextEditingController _kgCtrl;
  late final TextEditingController _repsCtrl;

  @override
  void initState() {
    super.initState();
    _kgCtrl   = TextEditingController(text: widget.entry.weightKg > 0 ? widget.entry.weightKg.toStringAsFixed(1) : '');
    _repsCtrl = TextEditingController(text: widget.entry.reps.toString());
  }

  @override
  void dispose() {
    _kgCtrl.dispose();
    _repsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rm = widget.entry.rmEstimated;
    final hasRm = rm > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF14141E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF242430)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Block badge + exercise name
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF00F5D4).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  widget.entry.exercise.blockName.isNotEmpty
                      ? widget.entry.exercise.blockName
                      : widget.entry.exercise.blockType.toUpperCase(),
                  style: const TextStyle(fontSize: 10, color: Color(0xFF00F5D4), fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(widget.entry.exercise.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 12),
          Row(
            children: [
              // Weight input
              Expanded(
                child: _Field(
                  controller: _kgCtrl,
                  label: 'Peso (kg)',
                  hint: '0.0',
                  suffix: 'kg',
                  onChanged: (v) {
                    widget.entry.weightKg = double.tryParse(v) ?? 0;
                    widget.onChanged();
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Reps input
              Expanded(
                child: _Field(
                  controller: _repsCtrl,
                  label: 'Reps',
                  hint: '${widget.entry.exercise.reps}',
                  suffix: 'reps',
                  isInt: true,
                  onChanged: (v) {
                    widget.entry.reps = int.tryParse(v) ?? widget.entry.exercise.reps;
                    widget.onChanged();
                    setState(() {});
                  },
                ),
              ),
            ],
          ),
          if (hasRm) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF00F5D4).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('RM estimado (Brzycki)',
                      style: TextStyle(fontSize: 12, color: Color(0xFF888888))),
                  Text('${rm.toStringAsFixed(1)} kg',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF00F5D4))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label, hint, suffix;
  final bool isInt;
  final ValueChanged<String> onChanged;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.suffix,
    required this.onChanged,
    this.isInt = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: isInt
          ? TextInputType.number
          : const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        if (isInt) FilteringTextInputFormatter.digitsOnly,
      ],
      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffix,
        labelStyle: const TextStyle(color: Color(0xFF888888), fontSize: 12),
        hintStyle: const TextStyle(color: Color(0xFF444444)),
        suffixStyle: const TextStyle(color: Color(0xFF888888), fontSize: 12),
        filled: true,
        fillColor: const Color(0xFF1E1E2E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF333344)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF333344)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF00F5D4)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      onChanged: onChanged,
    );
  }
}

class _SaveButton extends StatelessWidget {
  final bool saving, saved;
  final VoidCallback onPressed;
  const _SaveButton({required this.saving, required this.saved, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).padding.bottom + 16),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: saving ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: saved ? const Color(0xFF10B981) : const Color(0xFF00F5D4),
            foregroundColor: const Color(0xFF080810),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: saving
              ? const SizedBox(height: 20, width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF080810)))
              : Text(saved ? '✅ Guardado' : 'Guardar sesión',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ),
      ),
    );
  }
}
