import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/api_client.dart';
import '../../../core/constants.dart';
import '../../../models/schedule_slot.dart';
import '../../auth/auth_provider.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  List<ScheduleSlot> _slots = [];
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _sedes = [];
  int? _selectedSedeId;  // null = gimnasio central (sin filtro de sede)
  bool _sedeRestoredFromServer = false;
  String _gymName = 'Central';

  // 0 = esta semana, 1 = semana que viene, 2 = en dos semanas
  int _weekOffset = 0;
  static const int _maxWeekOffset = 2;

  // day_of_week per page index — DB uses 0=Mon, 1=Tue ... 6=Sun
  static const _orderedDow = [0, 1, 2, 3, 4, 5, 6];

  // Pages: pairs of days.
  static const _daysPerPage = 2;
  static const _pageCount = 4; // 3 full pairs + Sun alone

  late PageController _pageController;
  int _currentPage = 0;

  /// Returns the 7 dates (Mon–Sun) for the currently selected week.
  List<DateTime> get _weekDates {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1))
        .add(Duration(days: _weekOffset * 7));
    final base = DateTime(monday.year, monday.month, monday.day);
    return List.generate(7, (i) => base.add(Duration(days: i)));
  }

  @override
  void initState() {
    super.initState();
    // Start on today’s page (only relevant for the current week)
    final now = DateTime.now();
    final todayDow = now.weekday; // 1=Mon..7=Sun
    final todayPageIdx = todayDow == 7 ? 3 : (todayDow - 1) ~/ 2;
    _currentPage = todayPageIdx;
    _pageController = PageController(initialPage: todayPageIdx);

    _load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final monday    = _weekDates[0];
      final weekStart =
          '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
      final data     = await ApiClient.get('${AppConstants.schedulesUrl}?week_start=$weekStart');
      final rawSlots = data['slots'] as List<dynamic>? ?? [];
      final rawSedes = data['sedes'] as List<dynamic>? ?? [];
      final preferredSedeId = data['sede_id_preferred'];
      setState(() {
        _slots = rawSlots.map((s) => ScheduleSlot.fromJson(s as Map<String, dynamic>)).toList();
        _sedes = rawSedes.map((s) => s as Map<String, dynamic>).toList();
        _gymName = (data['gym'] as Map<String, dynamic>?)?['name'] as String? ?? 'Central';
        // Restore preferred sede from server only on first load
        if (!_sedeRestoredFromServer && preferredSedeId != null) {
          _selectedSedeId = preferredSedeId is int ? preferredSedeId : int.tryParse(preferredSedeId.toString());
          _sedeRestoredFromServer = true;
        }
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // Save sede preference to server in the background
  Future<void> _saveSedePref(int? sedeId) async {
    try {
      await ApiClient.post(
        AppConstants.sedePreferenceUrl,
        {'sede_id': sedeId},
      );
    } catch (_) {} // silent — preference save is best-effort
  }

  void _showSedeSelector() {
    if (_sedes.isEmpty) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF14141E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A3A),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const Text('Seleccioná tu sede',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFFF0F0F0))),
            const SizedBox(height: 14),
            // "Todas" option
            _SedeOption(
              label: _gymName,
              subtitle: 'Clases del gimnasio central',
              selected: _selectedSedeId == null,
              onTap: () {
                setState(() => _selectedSedeId = null);
                _saveSedePref(null);
                Navigator.of(context).pop();
              },
            ),
            ..._sedes.map((sede) => _SedeOption(
              label: sede['name'] as String,
              selected: _selectedSedeId == sede['id'],
              onTap: () {
                final id = sede['id'] as int;
                setState(() => _selectedSedeId = id);
                _saveSedePref(id);
                Navigator.of(context).pop();
              },
            )),
          ],
        ),
      ),
    );
  }


  List<ScheduleSlot> _slotsForDayIndex(int dayIndex) {
    final dow = _orderedDow[dayIndex];
    return _slots.where((s) {
      if (s.dayOfWeek != dow) return false;
      if (_selectedSedeId == null) {
        // Gimnasio central: solo clases sin sede específica
        if (s.sedeId != null) return false;
      } else {
        // Sede específica: solo clases de esa sede
        if (s.sedeId != _selectedSedeId) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  String _shortDayLabel(int dayIndex) {
    final date = _weekDates[dayIndex];
    const names = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    return '${names[dayIndex]} ${date.day}';
  }

  bool _isToday(int dayIndex) {
    final d = _weekDates[dayIndex];
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  void _changeWeek(int delta) {
    final next = (_weekOffset + delta).clamp(0, _maxWeekOffset);
    if (next == _weekOffset) return;
    setState(() {
      _weekOffset = next;
      _currentPage = 0;
    });
    _pageController.dispose();
    _pageController = PageController(initialPage: 0);
    _load(); // re-fetch with the new week_start
  }

  String _weekLabel() {
    if (_weekOffset == 0) return 'Esta semana';
    if (_weekOffset == 1) return 'Semana que viene';
    return 'En 2 semanas';
  }

  void _openDetail(ScheduleSlot slot, int dayIndex) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SlotDetailSheet(
        slot: slot,
        date: _weekDates[dayIndex],
        onDone: _load,
      ),
    );
  }

  String _pageLabel(int page) {
    final d1 = page * _daysPerPage;
    final d2 = d1 + 1;
    if (d2 >= 7) return _shortDayLabel(d1);
    return '${_shortDayLabel(d1)} · ${_shortDayLabel(d2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080810),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 12, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Grilla de clases',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFF0F0F0),
                      ),
                    ),
                  ),
                  // Sede dropdown pill (only when sedes available)
                  if (!_loading && _sedes.isNotEmpty)
                    GestureDetector(
                      onTap: _showSedeSelector,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _selectedSedeId != null
                              ? const Color(0xFF00F5D4).withOpacity(0.12)
                              : const Color(0xFF1A1A28),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _selectedSedeId != null
                                ? const Color(0xFF00F5D4).withOpacity(0.4)
                                : const Color(0xFF2A2A3A),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              size: 13,
                              color: _selectedSedeId != null
                                  ? const Color(0xFF00F5D4)
                                  : const Color(0xFF666666),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _selectedSedeId != null
                                  ? (_sedes.firstWhere(
                                      (s) => s['id'] == _selectedSedeId,
                                      orElse: () => {'name': 'Sede'},
                                    )['name'] as String)
                                  : _gymName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _selectedSedeId != null
                                    ? const Color(0xFF00F5D4)
                                    : const Color(0xFF888888),
                              ),
                            ),
                            const SizedBox(width: 3),
                            Icon(
                              Icons.expand_more_rounded,
                              size: 14,
                              color: _selectedSedeId != null
                                  ? const Color(0xFF00F5D4)
                                  : const Color(0xFF666666),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (!_loading)
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Color(0xFF666666), size: 20),
                      onPressed: _load,
                    ),
                ],
              ),
            ),

            // ── Week navigator ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, size: 22),
                    color: _weekOffset > 0
                        ? const Color(0xFF00F5D4)
                        : const Color(0xFF2A2A3A),
                    onPressed: _weekOffset > 0 ? () => _changeWeek(-1) : null,
                  ),
                  Text(
                    _weekLabel(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _weekOffset == 0
                          ? const Color(0xFFAAAAAA)
                          : const Color(0xFF00F5D4),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, size: 22),
                    color: _weekOffset < _maxWeekOffset
                        ? const Color(0xFF00F5D4)
                        : const Color(0xFF2A2A3A),
                    onPressed: _weekOffset < _maxWeekOffset ? () => _changeWeek(1) : null,
                  ),
                ],
              ),
            ),

            // ── Page indicator dots ──────────────────────────────────────
            if (!_loading && _error == null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      _pageLabel(_currentPage),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF00F5D4),
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: List.generate(_pageCount, (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _currentPage ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color: i == _currentPage
                              ? const Color(0xFF00F5D4)
                              : const Color(0xFF2A2A3A),
                        ),
                      )),
                    ),
                  ],
                ),
              ),

            // ── Content ──────────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF00F5D4)))
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.wifi_off_rounded, size: 40, color: Color(0xFF444444)),
                              const SizedBox(height: 12),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 32),
                                child: Text(_error!, textAlign: TextAlign.center,
                                    style: const TextStyle(color: Color(0xFF888888), fontSize: 13)),
                              ),
                              const SizedBox(height: 16),
                              TextButton(onPressed: _load, child: const Text('Reintentar')),
                            ],
                          ),
                        )
                      : PageView.builder(
                          controller: _pageController,
                          itemCount: _pageCount,
                          onPageChanged: (p) => setState(() => _currentPage = p),
                          itemBuilder: (_, page) {
                            final d1 = page * _daysPerPage;
                            final d2 = d1 + 1;
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _DayColumn(
                                    label: _shortDayLabel(d1),
                                    isToday: _isToday(d1),
                                    slots: _slotsForDayIndex(d1),
                                    onTap: (s) => _openDetail(s, d1),
                                  ),
                                ),
                                if (d2 < 7)
                                  Expanded(
                                    child: _DayColumn(
                                      label: _shortDayLabel(d2),
                                      isToday: _isToday(d2),
                                      slots: _slotsForDayIndex(d2),
                                      onTap: (s) => _openDetail(s, d2),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Day Column ─────────────────────────────────────────────────────────────────
class _DayColumn extends StatelessWidget {
  final String label;
  final bool isToday;
  final List<ScheduleSlot> slots;
  final void Function(ScheduleSlot) onTap;

  const _DayColumn({
    required this.label,
    required this.isToday,
    required this.slots,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Day header ──────────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isToday
                ? const Color(0xFF00F5D4).withOpacity(0.10)
                : const Color(0xFF0E0E18),
            border: Border(
              right: const BorderSide(color: Color(0xFF1A1A28)),
              bottom: BorderSide(
                color: isToday
                    ? const Color(0xFF00F5D4).withOpacity(0.35)
                    : const Color(0xFF1A1A28),
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isToday
                  ? const Color(0xFF00F5D4)
                  : const Color(0xFFAAAAAA),
            ),
          ),
        ),
        // ── Slots ───────────────────────────────────────────────────────
        Expanded(
          child: slots.isEmpty
              ? Center(
                  child: Text(
                    'Sin clases',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.15),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                  itemCount: slots.length,
                  itemBuilder: (_, i) => _MiniCard(
                    slot: slots[i],
                    onTap: () => onTap(slots[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

// ── Mini Card ──────────────────────────────────────────────────────────────────
class _MiniCard extends StatelessWidget {
  final ScheduleSlot slot;
  final VoidCallback onTap;
  const _MiniCard({required this.slot, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = slot.slotColor;
    final slotDate = DateTime.tryParse(slot.nextDate);
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final isPast = slotDate != null && slotDate.isBefore(todayDate);
    // PRESENTE shows for any attended slot — attendance is historical, always visible
    final isPresent = slot.isPresent;
    // RESERVADO only shows for future/today slots
    final isBooked = slot.isBooked && !isPast;
    final isFull = slot.isFull && !isBooked && !isPresent;
    const presentColor = Color(0xFF10B981); // green

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: isPresent
              ? presentColor.withOpacity(0.10)
              : isBooked
                  ? color.withOpacity(0.12)
                  : isFull ? const Color(0xFF111118) : const Color(0xFF14141E),
          border: Border.all(
            color: isPresent
                ? presentColor.withOpacity(0.5)
                : isBooked
                    ? color.withOpacity(0.5)
                    : isFull ? const Color(0xFF252530) : color.withOpacity(0.2),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Accent bar
            Container(
              width: 3,
              height: 60,
              decoration: BoxDecoration(
                color: isFull ? const Color(0xFF282832) : color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  bottomLeft: Radius.circular(10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      slot.className ?? 'Clase',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isFull
                            ? const Color(0xFF555566)
                            : const Color(0xFFEEEEEE),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          slot.startTime.substring(0, 5),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: isFull ? const Color(0xFF3A3A4A) : color,
                          ),
                        ),
                        if (isPresent) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: presentColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: presentColor.withOpacity(0.4)),
                            ),
                            child: const Text(
                              'PRESENTE',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                color: presentColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ] else if (isBooked) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.check_circle, size: 11, color: color),
                        ],
                      ],
                    ),
                    if (slot.capacity != null && !isBooked) ...[
                      const SizedBox(height: 2),
                      Text(
                        isFull
                            ? 'Lleno'
                            : slot.spotsLeft <= 3
                                ? '${slot.spotsLeft} lugar${slot.spotsLeft == 1 ? '' : 'es'}'
                                : '',
                        style: TextStyle(
                          fontSize: 9,
                          color: isFull
                              ? const Color(0xFF444455)
                              : const Color(0xFFF59E0B),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }
}

// ── Slot Detail Bottom Sheet ───────────────────────────────────────────────────
class _SlotDetailSheet extends StatefulWidget {
  final ScheduleSlot slot;
  final DateTime date;
  final VoidCallback onDone;

  const _SlotDetailSheet({required this.slot, required this.date, required this.onDone});

  @override
  State<_SlotDetailSheet> createState() => _SlotDetailSheetState();
}

class _SlotDetailSheetState extends State<_SlotDetailSheet> {
  bool _working = false;
  String? _feedback;
  bool _feedbackOk = true;
  late int _localBookedCount;

  @override
  void initState() {
    super.initState();
    _localBookedCount = widget.slot.bookedCount;
  }

  String get _classDate => DateFormat('yyyy-MM-dd').format(widget.date);

  Future<void> _book() async {
    setState(() { _working = true; _feedback = null; });
    try {
      final res = await ApiClient.post(
        '${AppConstants.bookingsUrl}?action=book',
        {'slot_id': widget.slot.id, 'class_date': _classDate},
      );
      setState(() {
        _feedbackOk = true;
        _feedback = res['message'] as String? ?? '¡Reserva confirmada!';
        _working = false;
        _localBookedCount++; // update counter immediately
      });
      widget.onDone();
      // Refresh member data so credits update on home screen
      if (mounted) context.read<AuthProvider>().refresh();
    } catch (e) {
      setState(() { _feedbackOk = false; _feedback = e.toString(); _working = false; });
    }
  }

  Future<void> _cancel() async {
    setState(() { _working = true; _feedback = null; });
    try {
      final res = await ApiClient.delete(
        '${AppConstants.bookingsUrl}?action=cancel&slot_id=${widget.slot.id}&class_date=$_classDate',
      );
      setState(() {
        _feedbackOk = true;
        _feedback = res['message'] as String? ?? 'Reserva cancelada.';
        _working = false;
      });
      widget.onDone();
      // Refresh member data so credits restore on home screen
      if (mounted) context.read<AuthProvider>().refresh();
    } catch (e) {
      setState(() { _feedbackOk = false; _feedback = e.toString(); _working = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final slot = widget.slot;
    final color = slot.slotColor;
    final isPresent = slot.isPresent;
    final isBooked = slot.isBooked;
    final isFull = slot.isFull && !isBooked && !isPresent;

    // Build date label without locale (avoids LocaleDataException)
    const dayNames = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    final dow = widget.date.weekday - 1; // 0=Mon..6=Sun
    final dayName = dayNames[dow.clamp(0, 6)];
    final dateStr = '$dayName ${widget.date.day} de ${DateFormat('MMMM').format(widget.date)}';

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.38,
      maxChildSize: 0.85,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF14141E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF2E2E3E),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 4, height: 26,
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    slot.className ?? 'Clase',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFFF0F0F0)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _InfoRow(icon: Icons.calendar_today_outlined, label: dateStr),
            _InfoRow(icon: Icons.schedule_outlined, label: slot.displayTime),
            if (slot.salaName != null) _InfoRow(icon: Icons.room_outlined, label: slot.salaName!),
            if (slot.instructorName != null) _InfoRow(icon: Icons.person_outline, label: slot.instructorName!),
            if (slot.capacity != null)
              _InfoRow(
                icon: Icons.people_outline,
                label: '$_localBookedCount / ${slot.capacity} reservas',
                valueColor: (_localBookedCount >= slot.capacity!) ? const Color(0xFFEF4444) : null,
              ),
            const SizedBox(height: 20),
            if (_feedback != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: (_feedbackOk ? const Color(0xFF00F5D4) : const Color(0xFFEF4444)).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: (_feedbackOk ? const Color(0xFF00F5D4) : const Color(0xFFEF4444)).withOpacity(0.4),
                  ),
                ),
                child: Text(
                  _feedback!,
                  style: TextStyle(
                    color: _feedbackOk ? const Color(0xFF00F5D4) : const Color(0xFFEF4444),
                    fontSize: 13,
                  ),
                ),
              ),
            SizedBox(
              width: double.infinity, height: 50,
              child: Builder(builder: (context) {
                final today = DateTime.now();
                final todayDate = DateTime(today.year, today.month, today.day);
                final isPast = widget.date.isBefore(todayDate);

                // Already attended — show green chip, no action
                if (isPresent)
                  return Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.verified_outlined, size: 18, color: Color(0xFF10B981)),
                        SizedBox(width: 8),
                        Text(
                          '¡Estuviste presente en esta clase!',
                          style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ],
                    ),
                  );

                if (isBooked && !isPast)
                  return OutlinedButton.icon(
                    onPressed: _working ? null : _cancel,
                    icon: _working
                        ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.cancel_outlined, size: 17),
                    label: Text(_working ? 'Cancelando...' : 'Cancelar reserva'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  );

                return ElevatedButton.icon(
                  onPressed: (_working || isFull || isPast) ? null : _book,
                  icon: _working
                      ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : Icon(isPast ? Icons.block_outlined : Icons.check_circle_outline, size: 17),
                  label: Text(
                    _working ? 'Reservando...'
                    : isPast  ? 'Clase pasada'
                    : isFull  ? 'Sin lugares'
                    :           'Reservar lugar',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (isFull || isPast) ? const Color(0xFF2A2A2A) : const Color(0xFF00F5D4),
                    foregroundColor: (isFull || isPast) ? const Color(0xFF555555) : const Color(0xFF080810),
                    disabledBackgroundColor: const Color(0xFF2A2A2A),
                    disabledForegroundColor: const Color(0xFF555555),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    elevation: 0,
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? valueColor;
  const _InfoRow({required this.icon, required this.label, this.valueColor});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Icon(icon, size: 15, color: const Color(0xFF555566)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 14, color: valueColor ?? const Color(0xFFCCCCCC)),
              ),
            ),
          ],
        ),
      );
}

// ── Sede Option (bottom sheet list row) ───────────────────────────────────────
class _SedeOption extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _SedeOption({
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFF1A1A28))),
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF00F5D4).withOpacity(0.12)
                    : const Color(0xFF1A1A28),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.location_on_rounded,
                size: 16,
                color: selected ? const Color(0xFF00F5D4) : const Color(0xFF444444),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: selected ? const Color(0xFF00F5D4) : const Color(0xFFF0F0F0),
                    ),
                  ),
                  if (subtitle != null)
                    Text(subtitle!, style: const TextStyle(fontSize: 11, color: Color(0xFF666666))),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded, color: Color(0xFF00F5D4), size: 18),
          ],
        ),
      ),
    );
  }
}
