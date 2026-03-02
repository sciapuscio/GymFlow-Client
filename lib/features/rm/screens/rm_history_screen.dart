import 'package:flutter/material.dart';
import '../../../core/api_client.dart';
import '../../../core/constants.dart';
import '../models/rm_models.dart';

class RmHistoryScreen extends StatefulWidget {
  final String? exerciseName;
  const RmHistoryScreen({super.key, this.exerciseName});

  @override
  State<RmHistoryScreen> createState() => _RmHistoryScreenState();
}

class _RmHistoryScreenState extends State<RmHistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // ── Tab 0: Exercises ────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _exercises = [];
  String? _selectedExercise;
  List<RmLog> _logs = [];
  double _pr = 0;
  bool _loadingExercises = true;
  bool _loadingLogs = false;
  String? _exerciseError;

  // ── Tab 1: WOD History ──────────────────────────────────────────────────────
  List<WodHistoryEntry> _wods = [];
  bool _loadingWods = false;
  bool _wodsLoaded = false;
  String? _wodError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && !_wodsLoaded) _fetchWodHistory();
    });
    _fetchExercises();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Exercises tab logic ─────────────────────────────────────────────────────
  Future<void> _fetchExercises() async {
    try {
      final body =
          await ApiClient.get('${AppConstants.rmCalculatorUrl}?action=exercises');
      final list = (body['exercises'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .toList();
      setState(() {
        _exercises = list;
        _loadingExercises = false;
      });
      if (widget.exerciseName != null) _fetchHistory(widget.exerciseName!);
    } on ApiException catch (e) {
      setState(() {
        _loadingExercises = false;
        _exerciseError = e.message;
      });
    } catch (e) {
      setState(() {
        _loadingExercises = false;
        _exerciseError = '$e';
      });
    }
  }

  Future<void> _fetchHistory(String name) async {
    setState(() {
      _loadingLogs = true;
      _selectedExercise = name;
    });
    try {
      final body = await ApiClient.get(
          '${AppConstants.rmCalculatorUrl}?action=history&exercise=${Uri.encodeComponent(name)}');
      final logs = (body['logs'] as List? ?? [])
          .map((e) => RmLog.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _logs = logs;
        _pr = double.tryParse((body['pr'] ?? '0').toString()) ?? 0;
        _loadingLogs = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _loadingLogs = false;
        _exerciseError = e.message;
      });
    } catch (e) {
      setState(() => _loadingLogs = false);
    }
  }

  // ── WOD History tab logic ───────────────────────────────────────────────────
  Future<void> _fetchWodHistory() async {
    setState(() {
      _loadingWods = true;
      _wodError = null;
    });
    try {
      final body = await ApiClient.get(
          '${AppConstants.rmCalculatorUrl}?action=wod-history');
      final list = (body['wods'] as List? ?? [])
          .map((e) => WodHistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _wods = list;
        _loadingWods = false;
        _wodsLoaded = true;
      });
    } on ApiException catch (e) {
      setState(() {
        _loadingWods = false;
        _wodError = e.message;
      });
    } catch (e) {
      setState(() {
        _loadingWods = false;
        _wodError = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080810),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14141E),
        foregroundColor: Colors.white,
        title: const Text(
          'Mi Progreso RM',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00F5D4),
          labelColor: const Color(0xFF00F5D4),
          unselectedLabelColor: const Color(0xFF888888),
          tabs: const [
            Tab(icon: Icon(Icons.fitness_center, size: 18), text: 'Ejercicios'),
            Tab(icon: Icon(Icons.calendar_month, size: 18), text: 'WODs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildExercisesTab(),
          _buildWodHistoryTab(),
        ],
      ),
    );
  }

  // ── Tab 0: Exercises (unchanged) ────────────────────────────────────────────
  Widget _buildExercisesTab() {
    if (_loadingExercises) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF00F5D4)));
    }
    if (_exerciseError != null) {
      return Center(
          child: Text(_exerciseError!,
              style: const TextStyle(color: Color(0xFFEF4444))));
    }
    return Row(
      children: [
        SizedBox(
          width: 160,
          child: _ExerciseList(
            exercises: _exercises,
            selected: _selectedExercise,
            onSelect: _fetchHistory,
          ),
        ),
        const VerticalDivider(width: 1, color: Color(0xFF242430)),
        Expanded(
          child: _selectedExercise == null
              ? const Center(
                  child: Text('Seleccioná un ejercicio',
                      style: TextStyle(color: Color(0xFF888888))))
              : _loadingLogs
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF00F5D4)))
                  : _LogDetail(
                      logs: _logs,
                      pr: _pr,
                      exerciseName: _selectedExercise!),
        ),
      ],
    );
  }

  // ── Tab 1: WOD History ──────────────────────────────────────────────────────
  Widget _buildWodHistoryTab() {
    if (_loadingWods) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF00F5D4)));
    }
    if (_wodError != null) {
      return Center(
          child: Text(_wodError!,
              style: const TextStyle(color: Color(0xFFEF4444))));
    }
    if (_wods.isEmpty && _wodsLoaded) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🏋️', style: TextStyle(fontSize: 48)),
              SizedBox(height: 12),
              Text(
                'Sin WODs registrados aún.',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                'Escaneá el QR al terminar un WOD\ny cargá tus pesos para verlos acá.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF888888), fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchWodHistory,
      color: const Color(0xFF00F5D4),
      backgroundColor: const Color(0xFF14141E),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _wods.length,
        itemBuilder: (_, i) => _WodCard(wod: _wods[i]),
      ),
    );
  }
}

// ── Exercise list panel (unchanged) ──────────────────────────────────────────
class _ExerciseList extends StatelessWidget {
  final List<Map<String, dynamic>> exercises;
  final String? selected;
  final ValueChanged<String> onSelect;
  const _ExerciseList(
      {required this.exercises, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    if (exercises.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'Sin registros aún.\nEscaneá el QR del WOD o usá la Calculadora RM.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF888888), fontSize: 12),
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: exercises.length,
      itemBuilder: (_, i) {
        final ex = exercises[i];
        final name = ex['exercise_name'] as String;
        final pr = double.tryParse(ex['pr']?.toString() ?? '0') ?? 0;
        final isSelected = name == selected;
        return GestureDetector(
          onTap: () => onSelect(name),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: isSelected
                ? const Color(0xFF00F5D4).withOpacity(0.08)
                : Colors.transparent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: TextStyle(
                        color: isSelected
                            ? const Color(0xFF00F5D4)
                            : Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                if (pr > 0)
                  Text('PR: ${pr.toStringAsFixed(1)} kg',
                      style: const TextStyle(
                          color: Color(0xFF888888), fontSize: 11)),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Log detail with chart (unchanged) ────────────────────────────────────────
class _LogDetail extends StatelessWidget {
  final List<RmLog> logs;
  final double pr;
  final String exerciseName;
  const _LogDetail(
      {required this.logs, required this.pr, required this.exerciseName});

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const Center(
          child: Text('Sin historial para este ejercicio.',
              style: TextStyle(color: Color(0xFF888888))));
    }
    final maxRm =
        logs.map((l) => l.rmEstimated).reduce((a, b) => a > b ? a : b);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pr > 0) _PrBadge(pr: pr),
          const SizedBox(height: 16),
          const Text('Evolución RM (kg)',
              style: TextStyle(color: Color(0xFF888888), fontSize: 12)),
          const SizedBox(height: 8),
          _SimpleBarChart(logs: logs, maxRm: maxRm),
          const SizedBox(height: 20),
          const Text('Historial',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...logs.reversed.map((log) => _LogRow(log: log)),
        ],
      ),
    );
  }
}

class _PrBadge extends StatelessWidget {
  final double pr;
  const _PrBadge({required this.pr});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFFFF6B35), Color(0xFFFF4500)]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🏆 ', style: TextStyle(fontSize: 20)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('RÉCORD PERSONAL',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white70,
                      letterSpacing: 1.2)),
              Text('${pr.toStringAsFixed(1)} kg',
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SimpleBarChart extends StatelessWidget {
  final List<RmLog> logs;
  final double maxRm;
  const _SimpleBarChart({required this.logs, required this.maxRm});

  @override
  Widget build(BuildContext context) {
    final chartLogs =
        logs.length > 12 ? logs.sublist(logs.length - 12) : logs;
    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: chartLogs.map((log) {
          final pct = maxRm > 0 ? log.rmEstimated / maxRm : 0.0;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 2, right: 2, bottom: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(log.rmEstimated.toStringAsFixed(0),
                      style: const TextStyle(
                          fontSize: 8, color: Color(0xFF888888))),
                  const SizedBox(height: 2),
                  Container(
                    height: (92 * pct).clamp(4, 92).toDouble(),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00F5D4),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(log.date.length >= 7 ? log.date.substring(5) : log.date,
                      style: const TextStyle(
                          fontSize: 7, color: Color(0xFF555566))),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  final RmLog log;
  const _LogRow({required this.log});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF14141E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(log.date,
              style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
          const Spacer(),
          Text('${log.weightKg.toStringAsFixed(1)} kg × ${log.reps} reps',
              style: const TextStyle(color: Colors.white, fontSize: 13)),
          const SizedBox(width: 12),
          Text('⚡ ${log.rmEstimated.toStringAsFixed(1)} kg',
              style: const TextStyle(
                  color: Color(0xFF00F5D4),
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ── WOD History card (NEW) ───────────────────────────────────────────────────
class _WodCard extends StatefulWidget {
  final WodHistoryEntry wod;
  const _WodCard({required this.wod});

  @override
  State<_WodCard> createState() => _WodCardState();
}

class _WodCardState extends State<_WodCard> {
  bool _expanded = false;

  String _formatDate(String raw) {
    // raw: 'YYYY-MM-DD'
    if (raw.length < 10) return raw;
    final parts = raw.split('-');
    if (parts.length != 3) return raw;
    const months = [
      '', 'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
    ];
    final m = int.tryParse(parts[1]) ?? 0;
    return '${parts[2]} ${m < months.length ? months[m] : parts[1]}. ${parts[0]}';
  }

  @override
  Widget build(BuildContext context) {
    final wod = widget.wod;
    final isManual = wod.sessionId == null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF14141E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isManual
              ? const Color(0xFF333345)
              : const Color(0xFF00F5D4).withOpacity(0.18),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isManual
                          ? const Color(0xFF242430)
                          : const Color(0xFF00F5D4).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        isManual ? '✏️' : '🏋️',
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Name + date
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          wod.sessionName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _formatDate(wod.sessionDate),
                          style: const TextStyle(
                              color: Color(0xFF888888), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  // Exercise count badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00F5D4).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${wod.entries.length} ejerc.',
                      style: const TextStyle(
                          color: Color(0xFF00F5D4),
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: const Color(0xFF555566),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // ── Entries (expandable) ──────────────────────────────────────────
          if (_expanded) ...[
            const Divider(height: 1, color: Color(0xFF242430)),
            ...wod.entries.map((entry) => _EntryRow(entry: entry)),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  final WodRmEntry entry;
  const _EntryRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              entry.exerciseName,
              style: const TextStyle(
                color: Color(0xFFCCCCCC),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            '${entry.weightKg.toStringAsFixed(1)} kg × ${entry.reps} reps',
            style: const TextStyle(color: Color(0xFF888888), fontSize: 12),
          ),
          const SizedBox(width: 10),
          Text(
            '⚡ ${entry.rmEstimated.toStringAsFixed(1)}',
            style: const TextStyle(
              color: Color(0xFF00F5D4),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
