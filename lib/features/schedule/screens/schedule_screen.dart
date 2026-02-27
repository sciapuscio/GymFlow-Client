import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/api_client.dart';
import '../../../core/constants.dart';
import '../../../models/schedule_slot.dart';
import '../../auth/auth_provider.dart';

// ── Layout constants ──────────────────────────────────────────────────────────
const double _kHourHeight = 64.0;          // px per hour
const double _kPxPerMin   = _kHourHeight / 60.0;
const double _kLabelWidth = 44.0;          // hour-label column width
const int    _kTotalHours = 24;

// ── Time helpers ──────────────────────────────────────────────────────────────
int _minsFromMidnight(String t) {
  final p = t.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

int _slotDurationMins(ScheduleSlot s) =>
    _minsFromMidnight(s.endTime) - _minsFromMidnight(s.startTime);

double _topForTime(String t)   => _minsFromMidnight(t) * _kPxPerMin;
double _heightForSlot(ScheduleSlot s) =>
    _slotDurationMins(s).clamp(15, 1440) * _kPxPerMin;

// ═══════════════════════════════════════════════════════════════════════════════
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});
  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  List<ScheduleSlot> _slots = [];
  bool _loading = true;
  String? _error;

  int _weekOffset = 0;
  static const int _maxWeekOffset = 2;
  static const _orderedDow  = [0, 1, 2, 3, 4, 5, 6];
  static const _daysPerPage = 2;
  static const _pageCount   = 4;

  late PageController _pageController;
  late PageController _headerPageController;
  int _currentPage = 0;

  /// Shared vertical ScrollController (hour labels + day columns in sync)
  final ScrollController _timeController = ScrollController();

  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  List<DateTime> get _weekDates {
    final now = DateTime.now();
    final monday = now
        .subtract(Duration(days: now.weekday - 1))
        .add(Duration(days: _weekOffset * 7));
    final base = DateTime(monday.year, monday.month, monday.day);
    return List.generate(7, (i) => base.add(Duration(days: i)));
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final todayDow    = now.weekday;
    final todayPageIdx = todayDow == 7 ? 3 : (todayDow - 1) ~/ 2;
    _currentPage = todayPageIdx;
    _pageController       = PageController(initialPage: todayPageIdx);
    _headerPageController = PageController(initialPage: todayPageIdx);

    // Sync header ↔ content page controllers
    _pageController.addListener(() {
      if (_headerPageController.hasClients &&
          _headerPageController.page != _pageController.page) {
        _headerPageController.jumpTo(_pageController.offset);
      }
    });

    _load();

    // Scroll to current time on first paint
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToNow());

    // Update now-line every minute
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _headerPageController.dispose();
    _timeController.dispose();
    _clockTimer?.cancel();
    super.dispose();
  }

  void _scrollToNow() {
    if (!_timeController.hasClients) return;
    // Start at 07:00 — clases casi nunca arrancan antes de las 7am
    const startHour = 7;
    _timeController.animateTo(
      startHour * _kHourHeight,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
    );
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final monday    = _weekDates[0];
      final weekStart =
          '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
      final data    = await ApiClient.get('${AppConstants.schedulesUrl}?week_start=$weekStart');
      final rawSlots = data['slots'] as List<dynamic>? ?? [];
      setState(() {
        _slots   = rawSlots.map((s) => ScheduleSlot.fromJson(s as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<ScheduleSlot> _slotsForDayIndex(int dayIndex) {
    final dow = _orderedDow[dayIndex];
    return _slots.where((s) => s.dayOfWeek == dow).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  String _shortDayLabel(int dayIndex) {
    final date  = _weekDates[dayIndex];
    const names = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    return '${names[dayIndex]} ${date.day}';
  }

  bool _isToday(int dayIndex) {
    final d = _weekDates[dayIndex];
    return d.year == _now.year && d.month == _now.month && d.day == _now.day;
  }

  void _changeWeek(int delta) {
    final next = (_weekOffset + delta).clamp(0, _maxWeekOffset);
    if (next == _weekOffset) return;
    setState(() { _weekOffset = next; _currentPage = 0; });
    _pageController.dispose();
    _headerPageController.dispose();
    _pageController       = PageController(initialPage: 0);
    _headerPageController = PageController(initialPage: 0);
    _load();
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
        slot: slot, date: _weekDates[dayIndex], onDone: _load,
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
            // ── Title ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 12, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Grilla de clases',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFFF0F0F0)),
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

            // ── Week navigator ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, size: 22),
                    color: _weekOffset > 0 ? const Color(0xFF00F5D4) : const Color(0xFF2A2A3A),
                    onPressed: _weekOffset > 0 ? () => _changeWeek(-1) : null,
                  ),
                  Text(
                    _weekLabel(),
                    style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: _weekOffset == 0 ? const Color(0xFFAAAAAA) : const Color(0xFF00F5D4),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, size: 22),
                    color: _weekOffset < _maxWeekOffset ? const Color(0xFF00F5D4) : const Color(0xFF2A2A3A),
                    onPressed: _weekOffset < _maxWeekOffset ? () => _changeWeek(1) : null,
                  ),
                ],
              ),
            ),

            // ── Content ────────────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF00F5D4)))
                  : _error != null
                      ? _buildError()
                      : _buildCalendar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() => Center(
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
  );

  Widget _buildCalendar() {
    return Column(
      children: [
        // ── Sticky day-name headers ───────────────────────────────────────
        Row(
          children: [
            SizedBox(width: _kLabelWidth), // spacer for hour labels
            Expanded(
              child: SizedBox(
                height: 38,
                child: PageView.builder(
                  controller: _headerPageController,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _pageCount,
                  itemBuilder: (_, page) {
                    final d1 = page * _daysPerPage;
                    final d2 = d1 + 1;
                    return Row(
                      children: [
                        Expanded(child: _DayHeader(label: _shortDayLabel(d1), isToday: _isToday(d1))),
                        if (d2 < 7) Expanded(child: _DayHeader(label: _shortDayLabel(d2), isToday: _isToday(d2))),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),

        // ── Page indicator ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(
            children: [
              Text(
                _pageLabel(_currentPage),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF00F5D4)),
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
                    color: i == _currentPage ? const Color(0xFF00F5D4) : const Color(0xFF2A2A3A),
                  ),
                )),
              ),
            ],
          ),
        ),

        // ── Time grid (scrollable vertically) ────────────────────────────
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hour labels (fixed left column)
              SizedBox(
                width: _kLabelWidth,
                child: SingleChildScrollView(
                  controller: _timeController,
                  physics: const NeverScrollableScrollPhysics(),
                  child: _HourLabels(),
                ),
              ),
              // Day columns (swipeable horizontally, scroll vertically)
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _pageCount,
                  onPageChanged: (p) {
                    setState(() => _currentPage = p);
                    _headerPageController.jumpTo(_pageController.offset);
                  },
                  itemBuilder: (_, page) {
                    final d1 = page * _daysPerPage;
                    final d2 = d1 + 1;
                    return NotificationListener<ScrollNotification>(
                      onNotification: (n) {
                        if (n is ScrollUpdateNotification && _timeController.hasClients) {
                          _timeController.jumpTo(n.metrics.pixels);
                        }
                        return false;
                      },
                      child: SingleChildScrollView(
                        child: SizedBox(
                          height: _kTotalHours * _kHourHeight,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _DayColumn(
                                  slots: _slotsForDayIndex(d1),
                                  isToday: _isToday(d1),
                                  now: _now,
                                  onTap: (s) => _openDetail(s, d1),
                                ),
                              ),
                              if (d2 < 7)
                                Expanded(
                                  child: _DayColumn(
                                    slots: _slotsForDayIndex(d2),
                                    isToday: _isToday(d2),
                                    now: _now,
                                    onTap: (s) => _openDetail(s, d2),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Hour Labels Column ────────────────────────────────────────────────────────
class _HourLabels extends StatelessWidget {
  const _HourLabels();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _kTotalHours * _kHourHeight,
      child: Stack(
        children: List.generate(_kTotalHours, (h) => Positioned(
          top: h * _kHourHeight - 7,
          left: 0, right: 0,
          child: Text(
            '${h.toString().padLeft(2, '0')}:00',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, color: Color(0xFF444455)),
          ),
        )),
      ),
    );
  }
}

// ── Day Header ────────────────────────────────────────────────────────────────
class _DayHeader extends StatelessWidget {
  final String label;
  final bool isToday;
  const _DayHeader({required this.label, required this.isToday});

  @override
  Widget build(BuildContext context) => Container(
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: isToday ? const Color(0xFF00F5D4).withOpacity(0.08) : const Color(0xFF0E0E18),
      border: Border(
        bottom: BorderSide(
          color: isToday ? const Color(0xFF00F5D4).withOpacity(0.4) : const Color(0xFF1A1A28),
        ),
        right: const BorderSide(color: Color(0xFF1A1A28)),
      ),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w700,
        color: isToday ? const Color(0xFF00F5D4) : const Color(0xFFAAAAAA),
      ),
    ),
  );
}

// ── Day Column (Stack with proportional time blocks) ──────────────────────────
class _DayColumn extends StatelessWidget {
  final List<ScheduleSlot> slots;
  final bool isToday;
  final DateTime now;
  final void Function(ScheduleSlot) onTap;

  const _DayColumn({
    required this.slots,
    required this.isToday,
    required this.now,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final nowMins = now.hour * 60 + now.minute;

    return Container(
      height: _kTotalHours * _kHourHeight,
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: Color(0xFF1A1A28))),
      ),
      child: Stack(
        children: [
          // ── Hour grid lines ──────────────────────────────────────────────
          ...List.generate(_kTotalHours, (h) => Positioned(
            top: h * _kHourHeight,
            left: 0, right: 0,
            child: Container(height: 1, color: const Color(0xFF1A1A28).withOpacity(0.5)),
          )),

          // ── Half-hour dashes ─────────────────────────────────────────────
          ...List.generate(_kTotalHours, (h) => Positioned(
            top: h * _kHourHeight + _kHourHeight / 2,
            left: 8, right: 8,
            child: Container(height: 1, color: const Color(0xFF1A1A28).withOpacity(0.25)),
          )),

          // ── Class blocks ──────────────────────────────────────────────────
          ...slots.map((slot) => Positioned(
            top:    _topForTime(slot.startTime),
            left:   2,
            right:  2,
            height: _heightForSlot(slot),
            child: _TimeBlock(slot: slot, onTap: () => onTap(slot)),
          )),

          // ── Now line (today only) ─────────────────────────────────────────
          if (isToday)
            Positioned(
              top: nowMins * _kPxPerMin - 1,
              left: 0, right: 0,
              child: Row(
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(child: Container(height: 1.5, color: const Color(0xFFEF4444))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Time Block (proportional height class card) ───────────────────────────────
class _TimeBlock extends StatelessWidget {
  final ScheduleSlot slot;
  final VoidCallback onTap;

  const _TimeBlock({required this.slot, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = slot.slotColor;
    final slotDate  = DateTime.tryParse(slot.nextDate);
    final todayDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final isPast    = slotDate != null && slotDate.isBefore(todayDate);
    final isPresent = slot.isPresent;
    final isBooked  = slot.isBooked && !isPast;
    final isFull    = slot.isFull && !isBooked && !isPresent;

    const presentColor = Color(0xFF10B981);
    final blockH = _heightForSlot(slot);
    final compact = blockH < 42;
    final tiny    = blockH < 28;

    Color bgColor;
    Color borderColor;
    if (isPresent) {
      bgColor     = presentColor.withOpacity(0.12);
      borderColor = presentColor.withOpacity(0.5);
    } else if (isBooked) {
      bgColor     = color.withOpacity(0.14);
      borderColor = color.withOpacity(0.55);
    } else if (isFull) {
      bgColor     = const Color(0xFF111118);
      borderColor = const Color(0xFF252530);
    } else {
      bgColor     = const Color(0xFF16161F);
      borderColor = color.withOpacity(0.25);
    }

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left accent bar
              Container(width: 3, color: isFull ? const Color(0xFF282832) : color),
              // Content
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(5, tiny ? 2 : 4, 4, 2),
        child: tiny
            // Very small: just time
            ? Text(
                slot.startTime.substring(0, 5),
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
                    color: isFull ? const Color(0xFF3A3A4A) : color),
                overflow: TextOverflow.clip,
                maxLines: 1,
              )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Time + status badge
                            Row(
                              children: [
                                Text(
                                  slot.startTime.substring(0, 5),
                                  style: TextStyle(
                                    fontSize: compact ? 9 : 10,
                                    fontWeight: FontWeight.w800,
                                    color: isFull ? const Color(0xFF3A3A4A) : color,
                                  ),
                                ),
                                if (isPresent) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: presentColor.withOpacity(0.25),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: const Text(
                                      'PRESENTE',
                                      style: TextStyle(
                                        fontSize: 7,
                                        fontWeight: FontWeight.w800,
                                        color: presentColor,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                ] else if (isBooked) ...[
                                  const SizedBox(width: 3),
                                  Icon(Icons.check_circle, size: 9, color: color),
                                ],
                              ],
                            ),
                            // Class name
                            if (!compact) ...[
                              const SizedBox(height: 1),
                              Text(
                                slot.className ?? 'Clase',
                                maxLines: blockH > 80 ? 3 : 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                  color: isFull ? const Color(0xFF555566) : const Color(0xFFEEEEEE),
                                ),
                              ),
                            ],
                            // Low capacity warning
                            if (!compact && !isBooked && !isPresent && slot.capacity != null) ...[
                              const SizedBox(height: 1),
                              if (isFull)
                                const Text('Sin lugares', style: TextStyle(fontSize: 8, color: Color(0xFF555566)))
                              else if (slot.spotsLeft <= 3)
                                Text(
                                  '${slot.spotsLeft} lugar${slot.spotsLeft == 1 ? '' : 'es'}',
                                  style: const TextStyle(fontSize: 8, color: Color(0xFFF59E0B)),
                                ),
                            ],
                          ],
                        ),
                ),
              ),
            ],
          ),
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
        _feedback   = res['message'] as String? ?? '¡Reserva confirmada!';
        _working    = false;
        _localBookedCount++;
      });
      widget.onDone();
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
        _feedback   = res['message'] as String? ?? 'Reserva cancelada.';
        _working    = false;
      });
      widget.onDone();
      if (mounted) context.read<AuthProvider>().refresh();
    } catch (e) {
      setState(() { _feedbackOk = false; _feedback = e.toString(); _working = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final slot      = widget.slot;
    final color     = slot.slotColor;
    final isPresent = slot.isPresent;
    final isBooked  = slot.isBooked;
    final isFull    = slot.isFull && !isBooked && !isPresent;

    const dayNames = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    final dow     = widget.date.weekday - 1;
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
                decoration: BoxDecoration(color: const Color(0xFF2E2E3E), borderRadius: BorderRadius.circular(2)),
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
            _InfoRow(icon: Icons.schedule_outlined,       label: slot.displayTime),
            if (slot.salaName != null)       _InfoRow(icon: Icons.room_outlined,    label: slot.salaName!),
            if (slot.instructorName != null) _InfoRow(icon: Icons.person_outline,   label: slot.instructorName!),
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
                  style: TextStyle(color: _feedbackOk ? const Color(0xFF00F5D4) : const Color(0xFFEF4444), fontSize: 13),
                ),
              ),
            SizedBox(
              width: double.infinity, height: 50,
              child: Builder(builder: (context) {
                final today     = DateTime.now();
                final todayDate = DateTime(today.year, today.month, today.day);
                final isPast    = widget.date.isBefore(todayDate);

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
                      ? const SizedBox(width: 15, height: 15,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : Icon(isPast ? Icons.block_outlined : Icons.check_circle_outline, size: 17),
                  label: Text(
                    _working ? 'Reservando...'
                    : isPast  ? 'Clase pasada'
                    : isFull  ? 'Sin lugares'
                    :           'Reservar lugar',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:        (isFull || isPast) ? const Color(0xFF2A2A2A) : const Color(0xFF00F5D4),
                    foregroundColor:        (isFull || isPast) ? const Color(0xFF555555) : const Color(0xFF080810),
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
          child: Text(label, style: TextStyle(fontSize: 14, color: valueColor ?? const Color(0xFFCCCCCC))),
        ),
      ],
    ),
  );
}
